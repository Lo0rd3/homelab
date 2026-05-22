# AdGuard-01

This is the main operations runbook for `adguard-01`.

This repo's current AdGuard flow is **restore-based**, not a blank first-run wizard flow.

That means this runbook assumes I have:
- Terraform create the Alpine LXC
- backup files staged on the Proxmox host
- Ansible perform the one-time bootstrap and restore
- Ansible maintain the steady-state config after that

## 1. Current tracked state

- LXC hostname `adguard-01`
- IP `192.168.1.252/24`
- gateway `192.168.1.254`
- Alpine LXC
- AdGuard Home running on the production IP
- `node_exporter` exposed on `192.168.1.252:9100`

## 2. Truth sources

Use these files as tracked source of truth:
- `terraform/environments/homelab/terraform.tfvars.example`
- `ansible/playbooks/adguard.yml`
- `ansible/playbooks/site.yml`
- `ansible/inventories/homelab/hosts.yml`
- `ansible/inventories/homelab/host_vars/adguard-01.yml`
- `ansible/inventories/homelab/host_vars/prox.yml`
- `ansible/roles/adguard/defaults/main.yml`
- `ansible/roles/proxmox_host_file_exports/defaults/main.yml`

## 3. Prerequisites and manual inputs

Before I run the bootstrap playbook, I need these files on `prox`:

- `/root/AdGuardHome.yaml`
- `/root/leases.json`

These are staged into the LXC by the Proxmox host step before the AdGuard role starts.

I also need a local SSH public key ready for the one-time bootstrap command, for example:

```bash
ls ~/.ssh/id_ed25519.pub
```

## 4. Terraform checks

From `terraform/environments/homelab`:

```bash
terraform fmt -check
terraform validate
```

## 5. Provision or update the LXC

```bash
source ../../../.env
terraform plan
terraform apply
```

## 6. Ansible checks

From `ansible/`:

```bash
ansible-playbook playbooks/adguard.yml --syntax-check
ansible-playbook playbooks/site.yml --syntax-check
```

## 7. Apply flow

### Run the one-time bootstrap and restore flow

Use this on a fresh `adguard-01` after Terraform creates the LXC:

```bash
ansible-playbook playbooks/adguard.yml --limit prox,adguard-01 \
  -e "adguard_ssh_bootstrap_public_key=$(cat ~/.ssh/id_ed25519.pub)"
```

This flow does all of these steps:
- stages `AdGuardHome.yaml` and `leases.json` from the Proxmox host into the LXC
- bootstraps SSH access inside the fresh Alpine LXC
- installs Python 3 for Ansible modules
- installs and configures AdGuard Home
- restores the tracked config and runtime lease state
- installs and starts `node_exporter`

### Apply steady-state config on later runs

After the host has already been bootstrapped, use the normal site playbook path:

```bash
ansible-playbook playbooks/site.yml --limit adguard-01
```

Use the bootstrap playbook again only when I am rebuilding a fresh LXC or repeating the restore-based migration flow.

## 8. Validation

### Check SSH and basic reachability

```bash
ssh root@192.168.1.252
ping -c 3 192.168.1.254
```

### Check AdGuard service and config

```bash
rc-service AdGuardHome status
/opt/AdGuardHome/AdGuardHome --config /etc/adguardhome/AdGuardHome.yaml --work-dir /var/lib/adguardhome --check-config
```

I expect:
- AdGuard Home service is running
- config check passes

### Check web UI and DNS on production IP

From another host on the LAN:

```bash
curl -I http://192.168.1.252
nslookup example.org 192.168.1.252
```

### DHCP checks

At this point, `adguard-01` should be the active DHCP server for this tracked service state.

I expect:
- `adguard-01` answers on the final production IP
- clients can renew or receive leases normally

### Monitoring checks

From `monitoring-01`:

```bash
curl -fsS http://192.168.1.252:9100/metrics >/dev/null
```

In Prometheus, I expect:
- `192.168.1.252:9100` is up

In Grafana, I expect:
- host metrics for `adguard-01` are visible

## 9. Recovery

If bootstrap fails on a fresh LXC:
- confirm `/root/AdGuardHome.yaml` exists on `prox`
- confirm `/root/leases.json` exists on `prox`
- confirm the SSH public key file exists locally
- rerun `playbooks/adguard.yml` with the bootstrap key arg

If AdGuard does not start:
- re-check `/etc/adguardhome/AdGuardHome.yaml`
- rerun the config check command
- inspect restored data under `/var/lib/adguardhome`

If DNS is wrong on the production IP:
- confirm `AdGuardHome.yaml` still matches `192.168.1.252`

If monitoring is missing:
- check the `node-exporter` service on `adguard-01`
- check Prometheus target health for `192.168.1.252:9100`

## 10. Related docs

- `docs/runbooks/platform-operations.md` for repo-wide apply order
- `ansible/README.md` for playbook entrypoints
