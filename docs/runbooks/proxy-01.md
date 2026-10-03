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

Additional configured upstreams:
- `vault.idios` → redirects to `https://lo0orde.duckdns.org`
- `lo0orde.duckdns.org` → `http://192.168.1.5:8000` (Vaultwarden VM 101)

## 2. Truth sources

Use these files as tracked source of truth:
- `terraform/environments/homelab/terraform.tfvars.example`
- `ansible/playbooks/proxy.yml`
- `ansible/playbooks/site.yml`
- `ansible/inventories/homelab/hosts.yml`
- `ansible/inventories/homelab/host_vars/proxy-01/main.yml`
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
sh ./run-playbook.sh playbooks/proxy.yml --syntax-check
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
sh ./run-playbook.sh playbooks/proxy.yml --limit proxy-01
```

For steady-state Nginx configuration only, after every required TLS file already
exists on the host:

```bash
ansible-playbook playbooks/site.yml --limit proxy-01
```

Do not use this path for an initial rebuild or when DuckDNS certificate issuance
is required. Use the dedicated wrapper command above so `acme_duckdns` receives
the required untracked `DUCKDNS_TOKEN`.

## 8. Validation

### Verify the proxy host

```bash
ssh debian@proxy-01
sudo nginx -t
systemctl status nginx --no-pager
curl -kI -H 'Host: proxmox.idios' https://127.0.0.1/
curl -kI -H 'Host: adguard.idios' https://127.0.0.1/
curl -kI -H 'Host: vault.idios' https://127.0.0.1/
curl -fsS http://127.0.0.1:9100/metrics >/dev/null
```

### Verify from a LAN client

Confirm your local DNS resolves the `.idios` names to `192.168.1.3`, then open:
- `https://proxmox.idios`
- `https://adguard.idios`
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
- **Vaultwarden**: strongly discouraged to embed because it is a password manager and depends on strict origin and websocket behavior

## 9. Backup and restore

`backup-01` collects the required TLS pair without stopping or reloading Nginx:

- `/etc/nginx/secrets/idios.crt` → `nginx/idios.crt`
- `/etc/nginx/secrets/idios.key` → `nginx/idios.key`

The files are stored under the independent Restic prefix
`homelab/proxy-01`. The certificate and key must be restored together; do not
restore one file from a different snapshot than the other.

After a backup has run, validate its snapshot and restore to a protected
temporary directory on `backup-01`:

```bash
ssh debian@backup-01
sudo -i
read -rsp 'B2 account ID: ' B2_ACCOUNT_ID; echo
read -rsp 'B2 account key: ' B2_ACCOUNT_KEY; echo
read -rsp 'B2 bucket: ' B2_BUCKET; echo
export B2_ACCOUNT_ID B2_ACCOUNT_KEY B2_BUCKET
export RESTIC_PASSWORD_FILE=/etc/homelab-backup/secrets/restic-password
repo="b2:${B2_BUCKET}:homelab/proxy-01"
restore_dir=$(mktemp -d /root/restore-proxy-01.XXXXXX)
restic -r "$repo" snapshots --tag proxy-01
restic -r "$repo" restore <snapshot-id> --target "$restore_dir"
manifest=$(find "$restore_dir" -type f -name manifest -print -quit)
test -n "$manifest"
payload=$(dirname "$manifest")
(cd "$payload" && sha256sum -c --strict checksums.sha256)
crt=$(find "$restore_dir" -type f -name idios.crt -print -quit)
key=$(find "$restore_dir" -type f -name idios.key -print -quit)
test -n "$crt" && test -n "$key"
```

Obtain credentials from the approved external secret source; do not source
`backup-runtime.conf`, which the runner parses as data. Restic preserves the
original staging path below `"$restore_dir"`, so use `"$crt"` and `"$key"`
rather than assumed paths. Compare the validated pair with the intended source
and copy both files back as root with their original ownership and modes.
Validate with `sudo nginx -t`, then reload Nginx only if the restored pair is
being put into service. Never commit TLS material, Restic credentials, private
keys, or password hashes; use untracked external variables for those values.

The tracked repository does not attest to a completed backup or restore; record
any live validation in the operator-managed backup inventory.

## 10. Recovery

If routing breaks:
- run `sudo nginx -t`
- inspect `/etc/nginx/conf.d/homelab-proxy.conf`
- reload with `sudo systemctl reload nginx`

If a route fails but Nginx is healthy:
- test the upstream directly from `proxy-01`
- confirm the upstream service is still reachable
- confirm local DNS still points the `.idios` names at `192.168.1.3`

## 11. Related docs

- `docs/runbooks/platform-operations.md` for repo-wide apply order
- `docs/runbooks/manual-recovery.md` for full-platform or service recovery
- `ansible/README.md` for playbook entrypoints
