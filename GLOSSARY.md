# Homelab infrastructure

This glossary defines the terms used to describe the homelab infrastructure,
its services, and its recovery procedures.

## Language

**Guest**:
A VM or LXC managed by Terraform. A **Guest** is not a Proxmox host or a Docker container.
_Avoid_: node, host, container

**Service**:
A homelab capability with its own **Guest**, playbook, and runbook. A **Service** may run a Docker Compose stack inside its **Guest**.
_Avoid_: app, stack, workload

**Service map**:
The mapping from each **Service** to its **Guest**. One **Service** has one **Guest**.
_Avoid_: inventory, host list

**Tracked configuration**:
Configuration stored in this repository and applied by Terraform or Ansible. **Tracked configuration** is not **Operator-managed data**.
_Avoid_: repo state, source of truth

**Operator-managed data**:
Service data that lives outside this repository and must survive a **Rebuild**. Some of it is stored as a **Service backup** in Backblaze B2; secrets and external enrollment state are supplied separately.
_Avoid_: operator-managed state, persistent state

**Rebuild**:
Recreating a **Guest** from **Tracked configuration**. A **Rebuild** does not restore **Operator-managed data**.
_Avoid_: redeploy, restore

**Restore**:
Copying backed-up **Operator-managed data** from Backblaze B2 back to a **Service**. A **Restore** follows a **Rebuild** when data was lost.
_Avoid_: rebuild, recovery

**Service backup**:
An archive of **Operator-managed data** produced for central backup. A **Service backup** is not the central Restic repository stored in Backblaze B2.
_Avoid_: export, dump
