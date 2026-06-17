# =============================================================================
# Azure VM Module — Cloud VM deployment target (Azure)
# =============================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

resource "azurerm_resource_group" "llm" {
  name     = "${var.name_prefix}-rg"
  location = var.location
  tags     = var.tags
}

# --- Networking ---

resource "azurerm_virtual_network" "llm" {
  name                = "${var.name_prefix}-vnet"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.llm.location
  resource_group_name = azurerm_resource_group.llm.name
  tags                = var.tags
}

resource "azurerm_subnet" "llm" {
  name                 = "${var.name_prefix}-subnet"
  resource_group_name  = azurerm_resource_group.llm.name
  virtual_network_name = azurerm_virtual_network.llm.name
  address_prefixes     = [var.subnet_cidr]
}

# --- Network Security Group (Firewall) ---

resource "azurerm_network_security_group" "llm" {
  name                = "${var.name_prefix}-nsg"
  location            = azurerm_resource_group.llm.location
  resource_group_name = azurerm_resource_group.llm.name

  security_rule {
    name                       = "allow-http-api"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-ssh"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-prometheus"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8000"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "llm" {
  subnet_id                 = azurerm_subnet.llm.id
  network_security_group_id = azurerm_network_security_group.llm.id
}

# --- Storage ---

resource "azurerm_managed_disk" "model_cache" {
  name                 = "${var.name_prefix}-model-cache"
  location             = azurerm_resource_group.llm.location
  resource_group_name  = azurerm_resource_group.llm.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.model_cache_size_gb
  tags                 = var.tags
}

# --- Compute ---

resource "azurerm_public_ip" "llm" {
  name                = "${var.name_prefix}-pip"
  location            = azurerm_resource_group.llm.location
  resource_group_name = azurerm_resource_group.llm.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "llm" {
  name                = "${var.name_prefix}-nic"
  location            = azurerm_resource_group.llm.location
  resource_group_name = azurerm_resource_group.llm.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.llm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.llm.id
  }

  tags = var.tags
}

resource "azurerm_linux_virtual_machine" "llm" {
  name                = "${var.name_prefix}-vm"
  location            = azurerm_resource_group.llm.location
  resource_group_name = azurerm_resource_group.llm.name
  size                = var.enable_gpu ? var.gpu_vm_size : var.cpu_vm_size
  admin_username      = var.admin_username

  network_interface_ids = [azurerm_network_interface.llm.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/templates/cloud_init.yaml.tpl", {
    hardware_type     = var.enable_gpu ? "gpu" : "cpu"
    deployment_target = "azure-vm"
    environment       = var.environment
  }))

  tags = merge(var.tags, {
    HardwareType = var.enable_gpu ? "gpu" : "cpu"
    Environment  = var.environment
  })
}

resource "azurerm_virtual_machine_data_disk_attachment" "model_cache" {
  managed_disk_id    = azurerm_managed_disk.model_cache.id
  virtual_machine_id = azurerm_linux_virtual_machine.llm.id
  lun                = 10
  caching            = "ReadWrite"
}

# --- Load Balancer ---

resource "azurerm_lb" "llm" {
  count               = var.enable_lb ? 1 : 0
  name                = "${var.name_prefix}-lb"
  location            = azurerm_resource_group.llm.location
  resource_group_name = azurerm_resource_group.llm.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = azurerm_public_ip.llm.id
  }

  tags = var.tags
}

resource "azurerm_lb_backend_address_pool" "llm" {
  count           = var.enable_lb ? 1 : 0
  loadbalancer_id = azurerm_lb.llm[0].id
  name            = "llm-backend"
}

resource "azurerm_lb_probe" "llm" {
  count           = var.enable_lb ? 1 : 0
  loadbalancer_id = azurerm_lb.llm[0].id
  name            = "llm-health"
  protocol        = "Http"
  port            = 8000
  request_path    = "/ready"
}

resource "azurerm_lb_rule" "llm" {
  count                          = var.enable_lb ? 1 : 0
  loadbalancer_id                = azurerm_lb.llm[0].id
  name                           = "llm-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 8000
  frontend_ip_configuration_name = "frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.llm[0].id]
  probe_id                       = azurerm_lb_probe.llm[0].id
}
