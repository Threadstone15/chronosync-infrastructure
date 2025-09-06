# Terraform skeleton for HCI

This folder contains a provider-agnostic skeleton. Replace provider block in main.tf with your HCI provider and implement modules for:

- network: create VLANs, subnets, DNS entries on your HCI platform
- compute: VM templates, sizing, images
- storage: attach persistent disks
- firewall/security groups: port rules for north/south segmentation

Follow your HCI provider docs and use `terraform init`, `terraform plan`, `terraform apply` after adding provider credentials.
