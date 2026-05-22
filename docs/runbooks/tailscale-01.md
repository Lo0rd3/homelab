# Tailscale-01

This is the main operations runbook for `tailscale-01`.

This host is the Tailscale subnet router and exit node.

## 1. Current tracked state

I expect this host to provide both:
- private access to my home LAN through the subnet route `192.168.1.0/24`
- optional internet egress through my home IP by using `tailscale-01` as an exit node

Tracked state:
- LXC hostname `tailscale-01`
- IP `192.168.1.2/24`
- gateway `192.168.1.254`
- DNS `192.168.1.252`
- Proxmox host TUN access enabled for CT `201`
- `node_exporter` exposed on `192.168.1.2:9100`

## 2. Truth sources

Use these files as tracked source of truth:
- `terraform/environments/homelab/terraform.tfvars.example`
- `ansible/playbooks/tailscale.yml`
- `ansible/playbooks/site.yml`
- `ansible/inventories/homelab/hosts.yml`
- `ansible/inventories/homelab/host_vars/tailscale-01.yml`
- `ansible/inventories/homelab/host_vars/prox.yml`
- `ansible/roles/tailscale/defaults/main.yml`
- `ansible/roles/proxmox_lxc_tunnel_access/defaults/main.yml`

## 3. Prerequisites and manual inputs

On first join, I need a valid Tailscale auth key passed as an external secret.

Later runs do not need the auth key unless I am re-authenticating the node.

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

I expect the LXC to come up with:
- hostname `tailscale-01`
- address `192.168.1.2/24`
- gateway `192.168.1.254`
- DNS `192.168.1.252`

## 6. Ansible checks

From `ansible/`:

```bash
ansible-playbook playbooks/tailscale.yml --syntax-check
ansible-playbook playbooks/site.yml --syntax-check
```

## 7. Apply flow

The TUN setup is a root-only Proxmox host step, so it is handled by Ansible on the Proxmox host instead of Terraform.

On the first join, pass the auth key from an external secret input:

```bash
ansible-playbook playbooks/tailscale.yml --limit prox,tailscale-01 \
  -e "tailscale_auth_key=tskey-example-replace-me"
```

This playbook applies the full setup at once:
- Proxmox host TUN access for the LXC
- Tailscale inside `tailscale-01`
- subnet route advertise
- exit-node advertise
- node_exporter for monitoring

## 8. Validation

### Tailscale checks on the LXC

```bash
ssh root@tailscale-01
tailscale status
tailscale ip -4
```

I expect `tailscale status` to show the subnet route and exit-node capability already advertised by the Ansible-managed config.

### Tailscale admin approval checks

In the Tailscale admin console, confirm:
- the node is enrolled
- subnet route `192.168.1.0/24` is approved
- exit-node capability is approved
- key expiry is disabled or managed for this router node

### Monitoring checks

On `monitoring-01` or from the Grafana/Prometheus UI, confirm:
- `192.168.1.2:9100` appears as an active Prometheus target
- `tailscale-01` host metrics appear in Grafana

Quick check from the monitoring VM:

```bash
curl -fsS http://192.168.1.2:9100/metrics >/dev/null
```

### Exit-node checks

Approve exit-node capability in the Tailscale admin console, then test internet traffic from a remote device through your home IP.

Good checks here are:

```bash
tailscale status
```

Then on a remote client:
- select `tailscale-01` as the exit node
- confirm your public IP matches home
- confirm you can still reach your home LAN services

## 9. Recovery

If Tailscale loses auth:
- rerun the Tailscale playbook with a fresh auth key

If routes or exit-node ads stop working:
- confirm the node is still advertising them with `tailscale status`
- re-approve in the Tailscale admin console if needed

If monitoring is missing:
- check `prometheus-node-exporter` on `tailscale-01`
- check Prometheus target health for `192.168.1.2:9100`

## 10. Related docs

- `docs/runbooks/platform-operations.md` for repo-wide apply order
- `ansible/README.md` for playbook entrypoints
