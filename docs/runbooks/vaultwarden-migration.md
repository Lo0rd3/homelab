# Vaultwarden operation and recovery

Vaultwarden runs as `vaultwarden/server:1.37.3` on Debian 12 VM 101
(`vaultwarden-01`, `192.168.1.5`). Clients use the canonical origin
`https://lo0orde.duckdns.org`; `vault.idios` is a LAN browser redirect.

## Current state

- Terraform owns VM 101; Ansible owns Docker and Compose.
- Persistent data is `/opt/vaultwarden/data`; runtime environment values are
  root-only at `/etc/vaultwarden/secrets.env`.

## Automated backup

`backup-01` collects the `vaultwarden-01` target into the independent Restic/B2
prefix `homelab/vaultwarden-01`. Retention is 7 daily, 4 weekly, 12 monthly,
and 2 yearly snapshots.

The source's root-owned, fixed forced command stops Compose, archives the full
`/opt/vaultwarden/data` tree, restarts Compose, and requires `/alive` to pass
before exporting. The full-data archive preserves SQLite with attachments,
sends, configuration, and RSA material as one quiesced set.
`/etc/vaultwarden/secrets.env` is outside that tree and is never exported.

`backup-01` can request neither a remote command nor a source path: its pinned
key is source-address restricted and invokes only the fixed exporter. Never
print or commit database contents, secret files, private keys, archive contents,
Restic credentials, or SSH material. Do not copy Alpine-only `ROCKET_*` or
`WEB_VAULT_*` settings into the Compose environment.

## Validation

- `docker compose -f /opt/compose/vaultwarden/compose.yml ps`
- `http://192.168.1.5:8000/alive` from `proxy-01`
- `https://lo0orde.duckdns.org/alive` with normal TLS verification
- `https://vault.idios` redirects to the canonical origin
- Android, browser extension, and web vault all show expected data after sync
- Prometheus scrapes `192.168.1.5:9100`

## Recovery

The validated Restic/B2 archive is the recovery source. If VM 101 fails,
recreate its replacement with Terraform and Ansible, provide the separately
retained `/etc/vaultwarden/secrets.env`, then restore the selected B2 archive.
Record redacted snapshot identifiers, checksums, and test results outside Git.

### Restore an automated backup

On `backup-01`, restore and inspect the snapshot only in an isolated protected
directory. First complete the credential-handoff procedure in Part 1, Step 3 of
`docs/runbooks/manual-recovery.md`; it exports the required B2 credentials and
sets `RESTIC_PASSWORD_FILE` without sourcing `backup-runtime.conf`.

```bash
sudo install -d -m 0700 /root/restore/vaultwarden-01/{snapshot,data}
sudo restic -r 'b2:<bucket>:homelab/vaultwarden-01' restore <snapshot> \
  --target /root/restore/vaultwarden-01/snapshot
manifest=$(sudo find /root/restore/vaultwarden-01/snapshot -type f -name manifest -print -quit)
test -n "$manifest"
payload=$(dirname "$manifest")
sudo sh -c 'cd "$1" && sha256sum -c --strict checksums.sha256' sh "$payload"
archive=$(sudo find /root/restore/vaultwarden-01/snapshot -type f -name vaultwarden-data.tar -print -quit)
test -n "$archive"
sudo tar -C /root/restore/vaultwarden-01/data -xf \
  "$archive"
sudo sqlite3 /root/restore/vaultwarden-01/data/data/db.sqlite3 'PRAGMA integrity_check;'
sudo sqlite3 /root/restore/vaultwarden-01/data/data/db.sqlite3 'PRAGMA foreign_key_check;'
```

`integrity_check` must return only `ok`; `foreign_key_check` must return no
rows. Stop if the manifest is missing or any checksum fails. Restic preserves
the random, absolute staging path beneath the restore target, so use the located
`"$archive"` rather than an assumed path. Transfer the validated archive to
`vaultwarden-01` through an authenticated administrator channel, then preserve
current state and install it:

```bash
sudo docker compose -f /opt/compose/vaultwarden/compose.yml -p vaultwarden stop
sudo mv /opt/vaultwarden/data /opt/vaultwarden/data.pre-restore-$(date -u +%Y%m%dT%H%M%SZ)
sudo install -d -o root -g root -m 0750 /opt/vaultwarden/data
sudo rm -f /opt/vaultwarden/data/db.sqlite3-wal
sudo tar -C /opt/vaultwarden -xf /root/restore/vaultwarden-data.tar
sudo docker compose -f /opt/compose/vaultwarden/compose.yml -p vaultwarden up -d
curl --fail --silent --show-error http://192.168.1.5:8000/alive
```

Removing a destination WAL before installing the archived database prevents a
stale WAL from being paired with the restored database.

For full-platform recovery and the shared Restic credential-handoff procedure,
see `docs/runbooks/manual-recovery.md`.
