#cloud-config
package_update: true
packages:
  - python3
  - python3-pip
  - curl

write_files:
  - path: /etc/llm-pipeline/config.env
    content: |
      HARDWARE_TYPE=${hardware_type}
      DEPLOYMENT_TARGET=${deployment_target}
      ENVIRONMENT=${environment}

runcmd:
  - echo "Azure VM bootstrap complete"
