# Keep host-only Proxmox steps in Ansible

Terraform creates the homelab guests and Ansible configures them. A small set of
Proxmox host steps, such as LXC tunnel access, stays in Ansible because the
Proxmox API token cannot perform them. A broader token would grant more
permissions than those steps need, so do not move the steps into Terraform
without revisiting that trade-off.
