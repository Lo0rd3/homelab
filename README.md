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
- `proxy-01` for the shared LAN-only reverse proxy for local `.idios` names
- `vaultwarden-01` for Vaultwarden on a Debian Docker VM
- `backup-01` for central Restic backups of operator-managed service state

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

Useful operator docs:

- `docs/runbooks/platform-operations.md` for the repo-wide flow
- `docs/runbooks/monitoring-01.md` for the monitoring VM
- `docs/runbooks/tailscale-01.md` for the Tailscale router LXC
- `docs/runbooks/adguard-01.md` for the AdGuard LXC
- `docs/runbooks/proxy-01.md` for the reverse proxy host
- `docs/runbooks/backup-01.md` for central backup operation and recovery
- `docs/runbooks/manual-recovery.md` for canonical full-platform and B2 service recovery
- `docs/runbooks/vaultwarden-migration.md` for Vaultwarden operation, automated backup, and recovery

## Tracked configuration and local artifacts

The tracked configuration paths are `terraform/environments/homelab/`,
`ansible/inventories/homelab/`, `ansible/playbooks/`, and `ansible/roles/`.
`terraform.tfvars.example` and `.env.example` are intentional examples; copy
them locally rather than committing provider values or secrets.

The repository ignores Terraform state and plans, repository-local Ansible
collections, TLS/private-key material, and restored backup directories. Keep
backup exports and restores in protected operator-managed locations, never in
this repository.

For validation that does not contact managed infrastructure, follow the
Terraform and Ansible syntax-check commands in
`docs/runbooks/platform-operations.md`. Commands in service runbooks that use
SSH, `curl`, or `ansible-playbook` without `--syntax-check` contact hosts and
must be run only when that is intended.

This repo is still evolving as I move more of my regular homelab services into it, but I want the structure to stay steady as the lab grows.
