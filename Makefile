SHELL := /bin/bash
NS ?= ibm-licensing

.PHONY: install uninstall audit all clean deps \
        install-direct uninstall-direct audit-direct

# --- via scripts ---
install:
	NS=$(NS) ./scripts/install.sh

uninstall:
	NS=$(NS) ./scripts/uninstall.sh

audit:
	NS=$(NS) ./scripts/audit.sh

all: uninstall install audit

# --- sans scripts, appels directs ---
install-direct:
	ansible-playbook -i inventories/hosts.yaml playbooks/10-install.yml -e "ns=$(NS)"

uninstall-direct:
	ansible-playbook -i inventories/hosts.yaml playbooks/10-uninstall.yml -e "ns=$(NS) purge_crds=false"

audit-direct:
	HOST=$$(oc -n $(NS) get route ibm-licensing-service-instance -o jsonpath='{.spec.host}'); \
	ansible-playbook -i inventories/hosts.yaml playbooks/20-audit.yml -e "ns=$(NS) ils_host=$$HOST api_service_port=8080"

# utilitaires
deps:
	ansible-galaxy collection install -r requirements.yaml

clean:
	rm -f playbooks/artifacts/pf_*.pid

reinstall: uninstall install
snapshot:
	@NS=$(NS); \
	HOST=$$(oc -n $$NS get route ibm-licensing-service-instance -o jsonpath='{.spec.host}'); \
	TOK=$$(oc -n $$NS get secret ibm-licensing-token -o jsonpath='{.data.token}' | base64 -d); \
	curl -sk "https://$$HOST/snapshot?token=$$TOK" -o playbooks/artifacts/ils-snapshot-$$(date +%FT%H%M%S).zip

metrics:
	@NS=$(NS); \
	oc -n $$NS port-forward svc/ibm-licensing-service-prometheus 18082:8081 >/dev/null 2>&1 & PF=$$!; \
	sleep 2; curl -s http://127.0.0.1:18082/metrics | head -n 20; kill $$PF

evidence:
	@tar -czf playbooks/artifacts/evidence-$$(date +%FT%H%M%S).tgz playbooks/artifacts

reset:
	@$(MAKE) uninstall && $(MAKE) install && $(MAKE) audit

