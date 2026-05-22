# Proxy-01

This is the main operations runbook for `proxy-01`.

`proxy-01` is the shared LAN-only reverse proxy VM.

## 1. Current tracked state

I expect this host to be:
- VM hostname `proxy-01`
- IP `192.168.1.3/24`
- gateway `192.168.1.254`
- reachable over Ansible as user `debian`
- Nginx reverse proxy for local `.idios` names
- `node_exporter` exposed on `192.168.1.3:9100`

Tracked proxy routes in repo:
- `proxmox.idios` → `https://192.168.1.1:8006`
- `adguard.idios` → `http://192.168.1.252`

Additional configured upstreams that are not backed by tracked Terraform guests in this repo:
- `booklore.idios` → `http://192.168.1.51:6060`
- `vault.idios` → `https://vault.lo0r.de`

## 2. Truth sources

Use these files as tracked source of truth:
- `terraform/environments/homelab/terraform.tfvars.example`
- `ansible/playbooks/proxy.yml`
- `ansible/playbooks/site.yml`
- `ansible/inventories/homelab/hosts.yml`
- `ansible/inventories/homelab/host_vars/proxy-01.yml`
- `ansible/roles/nginx/tasks/main.yml`

## 3. Prerequisites and manual inputs

Local TLS files on `proxy-01`:
- `/etc/nginx/secrets/idios.crt`
- `/etc/nginx/secrets/idios.key`

These files are manual operator inputs. They are required on the host before the Nginx role can apply successfully.

## 4. Terraform checks

From `terraform/environments/homelab`:

```bash
terraform fmt -check
terraform validate
```

## 5. Provision or update the VM

```bash
source ../../../.env
terraform plan
terraform apply
```

## 6. Ansible checks

From `ansible/`:

```bash
ansible-playbook playbooks/proxy.yml --syntax-check
ansible-playbook playbooks/site.yml --syntax-check
```

## 7. Apply flow

### Place the local TLS files on `proxy-01`

The Nginx role expects the certificate and key to already exist on the host before the playbook runs.

```bash
ssh debian@192.168.1.3
sudo mkdir -p /etc/nginx/secrets
sudo mv /path/to/idios.crt /etc/nginx/secrets/idios.crt
sudo mv /path/to/idios.key /etc/nginx/secrets/idios.key
sudo chown root:root /etc/nginx/secrets/idios.crt /etc/nginx/secrets/idios.key
sudo chmod 0640 /etc/nginx/secrets/idios.crt
sudo chmod 0600 /etc/nginx/secrets/idios.key
```

### Apply the reverse proxy

```bash
ansible-playbook playbooks/proxy.yml --limit proxy-01
```

Or as part of the full host config:

```bash
ansible-playbook playbooks/site.yml --limit proxy-01
```

## 8. Validation

### Verify the proxy host

```bash
ssh debian@proxy-01
sudo nginx -t
systemctl status nginx --no-pager
curl -kI -H 'Host: proxmox.idios' https://127.0.0.1/
curl -kI -H 'Host: adguard.idios' https://127.0.0.1/
curl -kI -H 'Host: booklore.idios' https://127.0.0.1/
curl -kI -H 'Host: vault.idios' https://127.0.0.1/
curl -fsS http://127.0.0.1:9100/metrics >/dev/null
```

### Verify from a LAN client

Confirm your local DNS resolves the `.idios` names to `192.168.1.3`, then open:
- `https://proxmox.idios`
- `https://adguard.idios`
- `https://booklore.idios`
- `https://vault.idios`

### Monitoring checks

On `monitoring-01` or in Prometheus, confirm:
- `192.168.1.3:9100` is up
- host metrics for `proxy-01` are visible

Quick check from the monitoring VM:

```bash
curl -fsS http://192.168.1.3:9100/metrics >/dev/null
```

If your client does not trust the local cert authority yet, the browser will warn until you install the CA or trust the leaf cert chain.

### Iframe and embedding limits

Reverse proxying helps, but it does not guarantee iframe embedding will work.

- **Proxmox**: poor iframe candidate due to admin-console security, origin sensitivity, and websocket complexity
- **AdGuard Home**: possible, but still an admin UI and not ideal for framing
- **BookLore**: the best candidate of the current set, but still verify headers and cookies
- **Vaultwarden**: strongly discouraged to embed because it is a password manager and depends on strict origin and websocket behavior

## 9. Recovery

If routing breaks:
- run `sudo nginx -t`
- inspect `/etc/nginx/conf.d/homelab-proxy.conf`
- reload with `sudo systemctl reload nginx`

If a route fails but Nginx is healthy:
- test the upstream directly from `proxy-01`
- confirm the upstream service is still reachable
- confirm local DNS still points the `.idios` names at `192.168.1.3`

## 10. Related docs

- `docs/runbooks/platform-operations.md` for repo-wide apply order
- `ansible/README.md` for playbook entrypoints
