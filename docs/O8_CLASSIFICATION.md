# O8 classification — ansible-ils

Date : 2026-10-01

## Decision

`KEEP / SPECIALIST / REQUALIFICATION_REQUIRED`

Canonical role:

> IBM License Service installation/audit/uninstall laboratory on OpenShift/CRC using Ansible + Helm.

This repository is not:
- the OpenShift cluster factory ;
- a shared platform services repository ;
- the generic GitOps owner.

## Hygiene actions performed

- removed committed Python `.venv` from current `main` ;
- removed local backup copies `.bak/.old` from current `main` ;
- added `.gitignore` ;
- removed a non-empty IBM entitlement credential from active defaults ;
- added `SECURITY.md`.

## Historical exposure boundary

A credential-like entitlement value had been committed in the public repository.

Deleting it from `main` does not erase Git history. Treat any usable historical value as compromised and rotate/revoke it.

## Evidence boundary

The repository contains historical snapshot ZIPs under `playbooks/artifacts/`.

They are retained for now because they may be unique evidence and have not been safely inspected as text through the GitHub connector.

Current classification:
- Ansible/Helm implementation = `IMPLEMENTED` ;
- historical CRC claims = `HISTORICAL_REFERENCE` ;
- current CRC runtime = `NOT_PROVEN` ;
- production = `NOT_CLAIMED`.

Do not delete the snapshot ZIPs until their contents have been reviewed for both evidence value and sensitive data.
