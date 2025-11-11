#!/usr/bin/env bash
set -euo pipefail
NS="${NS:-ibm-licensing}"
ANSIBLE_PYTHON_INTERPRETER="$(pwd)/.venv/bin/python" ansible-playbook -i inventories/hosts.yaml playbooks/10-uninstall.yml -e "ns=${NS} purge_crds=false"
