#!/usr/bin/env bash
set -euo pipefail
NS="${NS:-ibm-licensing}"
HOST="$(oc -n "${NS}" get route ibm-licensing-service-instance -o jsonpath='{.spec.host}')"
ANSIBLE_PYTHON_INTERPRETER="$(pwd)/.venv/bin/python" ansible-playbook -i inventories/hosts.yaml playbooks/20-audit.yml -e "ns=${NS} ils_host=${HOST} api_service_port=8080"
