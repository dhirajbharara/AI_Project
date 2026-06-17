#!/bin/bash
# EC2 user data — initial bootstrap before Ansible takes over
set -euo pipefail

echo "LLM Pipeline bootstrap starting..."
echo "Region: ${region}"
echo "Hardware: ${hardware_type}"
echo "Target: ${deployment_target}"

# Tag instance for Ansible inventory discovery
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
aws ec2 create-tags --resources "$INSTANCE_ID" \
  --tags Key=AnsibleManaged,Value=true \
         Key=HardwareType,Value=${hardware_type} \
         Key=DeploymentTarget,Value=${deployment_target} \
  --region ${region} || true

# Install minimal bootstrap tools
apt-get update -y
apt-get install -y python3 python3-pip curl

echo "Bootstrap complete — ready for Ansible configuration"
