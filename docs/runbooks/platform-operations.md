# Platform operations

This is the simple day-to-day flow I want to follow for this repo.

## Main order

When I change infrastructure or services, I want to think in this order:

1. Terraform
2. Proxmox host steps if needed
3. Ansible
4. validation

That keeps the split clear and helps me avoid weird half-applied changes.

## 1. Terraform checks

From `terraform/environments/homelab`:

```bash
terraform fmt -check
terraform validate
```

If I am making real infra changes:

```bash
source ../../../.env
terraform plan
terraform apply
```

## 2. When Proxmox host steps are needed

Some things do not fit well in Terraform with the current token setup.

Example:
- LXC tunnel access

When that happens, I want to use the Proxmox host playbook or role after Terraform creates the guest.

## 3. Ansible checks

From `ansible/`:

### Install pinned collections without infrastructure contact

The non-builtin modules used by the tracked roles are pinned in
`requirements.yml` and installed into the repository-local
`.ansible/collections` path. For an offline-safe setup, first obtain the exact
collection archives through an approved, separate artifact process and make
them available to Ansible's local cache. Then install without contacting Galaxy:

```bash
ansible-galaxy collection install --offline -r requirements.yml -p .ansible/collections
```

Do not run this command until the approved collection artifacts are present: in
offline mode it must fail rather than fetch an unpinned or unreviewed release.
With the pinned collections already installed, syntax checks do not contact
managed hosts:

```bash
ansible-inventory --graph
ansible-playbook playbooks/site.yml --syntax-check
```

For service-specific work, I should syntax-check the specific playbook too.

Examples:

```bash
ansible-playbook playbooks/monitoring.yml --syntax-check
ansible-playbook playbooks/tailscale.yml --syntax-check
sh ./run-playbook.sh playbooks/proxy.yml --syntax-check
ansible-playbook playbooks/adguard.yml --syntax-check
```

## 4. Apply Ansible

### Baseline host config

```bash
ansible-playbook playbooks/site.yml --limit '!proxy-01'
```

`site.yml` is not a complete rebuild entrypoint: it omits Vaultwarden and does
not provision the proxy TLS prerequisites. On a rebuild, do not include
`proxy-01` in this initial command: restore or issue its TLS material first,
then run the dedicated `proxy.yml` wrapper command. Run `vaultwarden.yml` and
the applicable service playbooks separately, following
`docs/runbooks/manual-recovery.md` when restoring state from B2.

### Service-specific runs

```bash
ansible-playbook playbooks/monitoring.yml --limit monitoring-01
ansible-playbook playbooks/tailscale.yml --limit prox,tailscale-01
sh ./run-playbook.sh playbooks/proxy.yml --limit proxy-01
ansible-playbook playbooks/vaultwarden.yml --limit vaultwarden-01
ansible-playbook playbooks/site.yml --limit adguard-01
ansible-playbook playbooks/backup.yml
```

If a playbook needs a secret at runtime, I want to pass it in as an external var instead of storing it in Git.

## 5. Secrets rule

I want to keep this simple:

- repo root `.env` for local provider-style values
- external Ansible vars for one-time secrets
- host-side secret files when the app expects them

I do not want to commit:
- passwords
- auth keys
- tokens
- real API credentials

For the central backup playbook, provide the required untracked secret vars:

```bash
ansible-playbook playbooks/backup.yml -e @../homelab-backup-secrets.yml
```

## 6. Validation after changes

After I apply something, I want to check:

- the guest is reachable
- the service is up
- the right ports respond
- Prometheus sees the target if it should be monitored
- Grafana shows the service or host if it is part of monitoring

For `backup-01`, run the manual service and timer checks in
`docs/runbooks/backup-01.md`. A successful syntax check does not prove that B2
credentials, SSH trust, a Restic snapshot, or an AdGuard restore works.

For `proxy-01`, I also want to check:
- `nginx -t` passes on the guest
- `proxmox.idios`, `adguard.idios`, and `vault.idios` resolve to `192.168.1.3`
- each local hostname returns a response through the reverse proxy
- the local cert and key exist on `proxy-01` under `/etc/nginx/secrets/`
- `192.168.1.3:9100` is visible in Prometheus

## 7. Rebuild rule

If I need to rebuild something, I want to treat the repo as the source of truth
for infrastructure and tracked configuration, not as a complete recovery
entrypoint.

That means:
- Terraform recreates the guest
- Proxmox host automation handles host-only exceptions
- Ansible applies baseline and dedicated service playbooks

`site.yml` alone cannot rebuild the platform: it omits Vaultwarden and does not
create proxy TLS prerequisites. Restore service state and supply external
secrets with the dedicated playbooks and the canonical
`docs/runbooks/manual-recovery.md` procedure.

If I have to do too many manual fixes, I should write them down or automate them.

## 8. Quick troubleshooting

### Terraform

```bash
terraform validate
terraform plan
```

### Ansible

```bash
ansible-inventory --graph
ansible all -m ping
```

### Monitoring VM

```bash
ssh debian@monitoring-01
cd /opt/compose/monitoring
docker compose --env-file monitoring.env -f compose.yml ps
docker compose --env-file monitoring.env -f compose.yml logs --tail=100
```

Prometheus, Grafana, Alertmanager, node-exporter, and cAdvisor on
`monitoring-01` are administrative endpoints and bind only to `127.0.0.1`.
Review `docker compose --env-file monitoring.env -f compose.yml config` after
changes; do not expose them on the LAN without an approved reverse-proxy path.

### Tailscale router

```bash
ssh root@tailscale-01
tailscale status
```

### Reverse proxy

```bash
ssh debian@proxy-01
sudo nginx -t
curl -kI -H 'Host: proxmox.idios' https://127.0.0.1/
curl -kI -H 'Host: adguard.idios' https://127.0.0.1/
curl -kI -H 'Host: vault.idios' https://127.0.0.1/
curl -fsS http://127.0.0.1:9100/metrics >/dev/null
```

See `docs/runbooks/proxy-01.md` for the full proxy flow and the current iframe limitations.
See `docs/runbooks/backup-01.md` for central backup failure and restore flow.
See `docs/runbooks/vaultwarden-migration.md` for Vaultwarden Docker operation,
automated backup and Restic/B2 recovery for VM 101.
See `docs/runbooks/manual-recovery.md` for full-platform and B2 service recovery.

## 9. Small rule for future me

Before I change anything, I want to ask:

1. is this Terraform, Proxmox host, or Ansible?
2. what is the smallest safe order to apply it?
3. how will I verify it after?
