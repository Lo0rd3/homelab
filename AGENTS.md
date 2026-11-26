# Homelab IaC agent guide

## What this repo manages

This repository manages a Proxmox homelab with Terraform and Ansible.

- Terraform creates VMs and LXCs.
- Ansible configures guests and services.
- Ansible also handles the small Proxmox host steps that Terraform cannot perform.
- Docker Compose runs inside selected VMs.

Read [README.md](README.md) for the repository map and [platform operations](docs/runbooks/platform-operations.md) for the full operator flow.

## Safety boundary

Run these checks without contacting managed infrastructure:

```bash
cd terraform
terraform fmt -check -recursive

cd environments/homelab
terraform validate

cd ../../../ansible
ansible-inventory --graph
ansible-playbook playbooks/site.yml --syntax-check
```

For a service change, syntax-check its specific playbook. Use
`sh ./run-playbook.sh playbooks/proxy.yml --syntax-check` for the proxy.
Pinned Ansible collections must already exist in `.ansible/collections`.
Do not fetch unpinned collections from Galaxy during validation.

Treat Terraform plans, Ansible runs without `--syntax-check`, SSH, `curl`,
`ansible -m ping`, B2, and DuckDNS as live operations. Ask before running them.
Ask before any command that applies, changes, restores, or deletes infrastructure
or service data.

Keep credentials, private keys, TLS material, `.env`, real `terraform.tfvars`,
Terraform state, plans, generated runtime files, and restored backup data out of
Git. Use external variables or host-side secret files.

## Repository map

- `terraform/environments/homelab/`: environment inputs and guest instances.
- `terraform/modules/`: reusable VM and LXC definitions.
- `ansible/inventories/homelab/`: hosts and group or host variables.
- `ansible/playbooks/`: thin service and platform entrypoints.
- `ansible/roles/`: reusable host and service configuration.
- `docs/runbooks/`: operator procedures and recovery instructions.
- `docs/agents/`: issue, triage, and domain-documentation conventions.

## Services

| Service | Guest | Type | Playbook | Runbook |
| --- | --- | --- | --- | --- |
| Monitoring | `monitoring-01` | VM | [`monitoring.yml`](ansible/playbooks/monitoring.yml) | [`monitoring-01.md`](docs/runbooks/monitoring-01.md) |
| Tailscale | `tailscale-01` | LXC | [`tailscale.yml`](ansible/playbooks/tailscale.yml) | [`tailscale-01.md`](docs/runbooks/tailscale-01.md) |
| AdGuard | `adguard-01` | LXC | [`adguard.yml`](ansible/playbooks/adguard.yml) or [`site.yml`](ansible/playbooks/site.yml) | [`adguard-01.md`](docs/runbooks/adguard-01.md) |
| Reverse proxy | `proxy-01` | VM | [`proxy.yml`](ansible/playbooks/proxy.yml) | [`proxy-01.md`](docs/runbooks/proxy-01.md) |
| Vaultwarden | `vaultwarden-01` | VM | [`vaultwarden.yml`](ansible/playbooks/vaultwarden.yml) | [`vaultwarden-migration.md`](docs/runbooks/vaultwarden-migration.md) |
| Central backup | `backup-01` | VM | [`backup.yml`](ansible/playbooks/backup.yml) | [`backup-01.md`](docs/runbooks/backup-01.md) |

Use [manual recovery](docs/runbooks/manual-recovery.md) for a full rebuild or a
service restore. `site.yml` is not a complete rebuild entrypoint.

## Known traps

- Apply changes in this order: Terraform, required Proxmox host steps, Ansible,
  then validation.
- `site.yml` omits Vaultwarden and proxy TLS prerequisites.
- Proxy TLS material must exist before applying the proxy playbook.
- When an address changes, update Terraform, inventory, monitoring targets, and
  backup allowlists together.
- Monitoring administrative endpoints bind to localhost. Do not expose them on
  the LAN without an approved reverse-proxy path.
- A syntax check does not prove live service health, credentials, SSH trust,
  backup snapshots, or restore validity.

## Change checklist

Before finishing a change:

1. Identify whether it belongs in Terraform, a Proxmox host step, or Ansible.
2. Run the relevant offline checks.
3. Update the relevant runbook when behavior or operator steps change.
4. Keep addresses synchronized across every tracked consumer.
5. Keep secrets, state, plans, and service backups outside Git.

## Agent workflows

- GitHub issues are managed with `gh`; read
  [the issue tracker guide](docs/agents/issue-tracker.md).
- Read issues with `gh` as needed. Ask before remote writes, including creating,
  editing, commenting on, closing, assigning, or relabeling issues.
- Use the canonical labels documented in
  [triage labels](docs/agents/triage-labels.md).
- Read [domain documentation](docs/agents/domain.md), `GLOSSARY.md`, and
  applicable ADRs before changing domain terminology or architecture.
