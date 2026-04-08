# Homelab IaC

This is my homelab repo.

I use it to manage my Proxmox setup with Infrastructure as Code in a way that stays simple, reusable, and easy to grow over time.

## What I use

- **Terraform** for infrastructure
- **Ansible** for host setup and service configuration
- **Docker Compose** inside VMs when a service fits better as a small stack

## Main approach

I try to keep the split clear:

- **Terraform** creates VMs and LXCs
- **Ansible** configures the guests and installs services
- **Proxmox host automation** handles the small host-only steps that do not fit cleanly in Terraform with the current setup

## Service pattern

- **VMs** are for bigger Docker-based stacks or workloads that require it
- **LXCs** are for smaller standalone services

- the goal is to keep the repo modular so I can add services without reworking the whole structure each time.

## Current services

- `monitoring-01` for the monitoring stack
- `tailscale-01` for subnet routing and exit-node access
- `adguard-01` for AdGuard Home

## Repo layout

```text
.
├── ansible/
├── docs/
└── terraform/
    ├── environments/
    │   └── homelab/
    └── modules/
        ├── lxc/
        └── vm/
```

## What matters most here

- keep infrastructure and configuration separated
- keep things light enough for homelab hardware
- prefer simple patterns over clever ones
- make rebuilds possible
- learn

## Working in this repo

Typical flow:

1. update the environment inputs in `terraform/environments/homelab`
2. apply infrastructure changes with Terraform
3. run Ansible from `ansible/` to configure the hosts
4. validate service health with the relevant runbooks

This repo is still evolving as I move more of my regular homelab services into it, but I want the structure to stay steady as the lab grows.
