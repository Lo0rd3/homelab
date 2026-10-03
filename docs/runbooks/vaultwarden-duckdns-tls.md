# Vaultwarden private TLS with DuckDNS

This runbook gives a LAN-only Vaultwarden endpoint a publicly trusted Let's Encrypt
certificate. DNS-01 validation updates a DuckDNS TXT record, so no inbound Internet
port or public Vaultwarden address is required.

## Prerequisites

1. Create a free `*.duckdns.org` hostname and obtain its token from DuckDNS.
2. Choose an ACME account email address.
3. Store the DuckDNS token in the untracked repository-root environment file
   `.env`. Set `DUCKDNS_TOKEN=<token>` there; `.env.example` documents the key.
   `.env` is ignored by Git. The wrapper
   exports it only for the Ansible process.

   The role renders the token to `/etc/lego/duckdns.env` as `root:root`, mode
   `0600`; neither the controller `.env` nor the rendered file belongs in Git.
4. Add an AdGuard DNS rewrite for the DuckDNS hostname to `192.168.1.3`.
   The tracked `adguard_dns_rewrites` declaration manages this through the AdGuard
   API. Set `ADGUARD_ADMIN_USERNAME` and `ADGUARD_ADMIN_PASSWORD` in root `.env`
   before applying the AdGuard playbook. The role permits only the AdGuard host's
   own primary address or loopback as its API endpoint.

## Inventory changes

Set the following non-secret values in `ansible/inventories/homelab/host_vars/proxy-01/main.yml`:

```yaml
acme_duckdns_enabled: true
acme_duckdns_domain: example.duckdns.org
acme_duckdns_email: admin@example.net
```

For the Vaultwarden vhost, replace `vault.idios` with the DuckDNS hostname and set:

```yaml
tls_certificate_path: /etc/nginx/secrets/example.duckdns.org.crt
tls_private_key_path: /etc/nginx/secrets/example.duckdns.org.key
```

Set `vaultwarden_docker_domain` in `host_vars/vaultwarden-01.yml` to
`https://example.duckdns.org`.

To preserve a familiar LAN address without creating a second Vaultwarden origin,
add a `vault.idios` vhost with `redirect_url: https://example.duckdns.org`. AdGuard
must rewrite `example.duckdns.org` to the proxy LAN address so the redirected
connection stays inside the LAN.

## Apply and verify

1. Run `sh ./run-playbook.sh playbooks/adguard.yml --limit adguard-01` from
   `ansible/` to reconcile the local DNS rewrite.
2. Run `sh ./run-playbook.sh playbooks/proxy.yml --limit proxy-01`.
3. Run `ansible-playbook playbooks/vaultwarden.yml --limit vaultwarden-01` after
   the Debian Docker VM and its root-only runtime environment file are ready.
4. Check the active certificate without bypassing validation:

   ```sh
   openssl s_client -connect example.duckdns.org:443 -servername example.duckdns.org \
     -verify_return_error </dev/null
   ```

5. Confirm the renewal timer with
   `systemctl status duckdns-certificate-renew.timer` on `proxy-01`.

The role uses Lego's DuckDNS DNS provider. Lego writes a bundled server certificate
to its state directory, deploys it atomically to Nginx, validates Nginx, and reloads
only after a successful ACME operation.
