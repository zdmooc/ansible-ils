# ansible-ils — IBM License Service on OpenShift (CRC) via Ansible + Helm

> Déploiement idempotent d’**IBM License Service (ILS)** sur **OpenShift Local/CRC** avec Ansible, Helm, Make et scripts.

---

## Sommaire
- [Objectifs](#objectifs)
- [Architecture et principes](#architecture-et-principes)
- [Prérequis](#prérequis)
- [Arborescence du projet](#arborescence-du-projet)
- [Variables clés](#variables-clés)
- [Makefile : cibles utiles](#makefile--cibles-utiles)
- [Playbooks et rôles](#playbooks-et-rôles)
- [Déploiement pas-à-pas](#déploiement-pas-à-pas)
- [Vérifications d’audit](#vérifications-daudit)
- [Snapshot et métriques](#snapshot-et-métriques)
- [Désinstallation et purge](#désinstallation-et-purge)
- [Notes de compatibilité](#notes-de-compatibilité)
- [Sécurité et bonnes pratiques](#sécurité-et-bonnes-pratiques)
- [Dépannage](#dépannage)
- [CI/CD (optionnel)](#cicd-optionnel)
- [Licence](#licence)

---

## Objectifs
- **Installer** ILS en mode *cluster-scoped* sur un cluster OpenShift (CRC) de façon **reproductible** et **idempotente**.
- **Vérifier** automatiquement la disponibilité via `/version`, `/health` et l’endpoint **Prometheus** `:8081/metrics`.
- **Exporter** un **snapshot** d’évidence (preuve d’installation et d’état) en ZIP.
- **Désinstaller** proprement tous les artefacts namespacés et cluster-scoped. Purge CRDs **optionnelle**.

---

## Architecture et principes
- **Pattern Helm en 2 passes** :
  1) Pass **CRDs + Operator + RBAC**
  2) Pass **Instance (CR IBMLicensing) + Services**
- **Namespace par défaut** : `ibm-licensing`.
- **Route TLS reencrypt** vers le service `ibm-licensing-service-instance` (port cible **8080**).
- **Endpoints** exposés par la Route : `https://<host>/version`, `https://<host>/health?token=<...>`, `https://<host>/snapshot?token=<...>`.
- **Métriques** via le service `ibm-licensing-service-prometheus` (port **8081**), consommables en **port-forward** local.

---

## Prérequis
- Cluster **CRC/OpenShift** opérationnel et connecté : `oc whoami` doit fonctionner.
- **Cluster-admin** ou permissions équivalentes pour CRDs/RBAC cluster-scoped.
- **Ansible** et **Helm** installés sur la machine d’exécution.
- Optionnel : accès à l’IBM Entitled Registry (si images privées) ; ce projet supporte aussi un déploiement sans secret.

> **Note PEP 668 (Debian/Ubuntu)** : si `pip` est « externally-managed », utiliser un **virtualenv** local :
>
> ```bash
> python3 -m venv .venv
> source .venv/bin/activate
> python3 -m pip install -U pip wheel
> python3 -m pip install -U kubernetes openshift
> ```

---

## Arborescence du projet
```
ansible-ils/
├── ansible.cfg
├── inventories/
│   ├── hosts.yaml
│   └── group_vars/
│       └── all.yml
├── playbooks/
│   ├── 00-prereqs.yml           # (optionnel)
│   ├── 10-install.yml
│   ├── 10-uninstall.yml
│   ├── 20-audit.yml
│   └── artifacts/               # snapshots, values, PID PF, etc.
├── roles/
│   ├── install/
│   │   ├── defaults/main.yml    # variables par défaut (chart, repo, ns, route)
│   │   ├── tasks/
│   │   │   ├── main.yml         # orchestrateur + route
│   │   │   ├── pass1_crds_rbac_operator.yml
│   │   │   └── pass2_cr_instance.yml
│   │   └── templates/values-overrides.yaml.j2
│   └── uninstall/
│       └── tasks/main.yml       # CR, Deployments, Services, Route, RBAC, CRDs (optionnel)
├── playbooks/roles/audit/       # rôle d’audit (inclus par 20-audit.yml)
│   ├── defaults/main.yml
│   └── tasks/main.yml
├── scripts/
│   ├── install.sh
│   ├── uninstall.sh
│   └── audit.sh
├── Makefile
└── requirements.yaml
```

---

## Variables clés
Variables par défaut (voir `roles/install/defaults/main.yml`) :

```yaml
ns: ibm-licensing

# Helm repo + chart
helm_repo_name: ibm-helm-repo
helm_repo_url: https://raw.githubusercontent.com/IBM/charts/master/repo/ibm-helm
release: ibm-licensing-cluster-scoped
chart_repo: ibm-helm-repo
chart_name: ibm-licensing-cluster-scoped
chart_version: 4.2.19+20251031.131912.0

# Entitlement (optionnel)
entitlement_key: ""        # vide = pas de secret créé
entitlement_user: cp
entitlement_server: cp.icr.io
entitlement_secret_name: ibm-entitlement-key

# Route
route_name: ibm-licensing-service-instance
```

Surcharges possibles via `inventories/group_vars/all.yml` ou `-e` Ansible :

```yaml
ns: ibm-licensing
entitlement_key: "<clé si besoin>"
```

---

## Makefile : cibles utiles
| Cible | Action |
|---|---|
| `make install` | Installe ILS via `scripts/install.sh` (pass1/2 + Route). |
| `make uninstall` | Désinstalle ILS (namespaced + RBAC cluster). CRDs **conservées**. |
| `make audit` | Lance l’audit (Route `/version`, `/health`, métriques, snapshot). |
| `make all` | `uninstall` → `install` → `audit`. |
| `make reinstall` | `uninstall` → `install`. |
| `make snapshot` | Télécharge un snapshot ILS via la Route. |
| `make metrics` | Port-forward Prometheus et montre un extrait de `/metrics`. |
| `make evidence` | Archive `playbooks/artifacts/` en tar.gz daté. |
| `make clean` | Nettoie les PID de port-forward. |

Namespace alternatif :
```bash
make all NS=ibm-licensing
```

---

## Playbooks et rôles
### 10-install.yml
- Rôle `install` :
  - Assure le namespace.
  - Ajoute/actualise le repo Helm.
  - **Pass 1** : rend le chart en manifest, applique CRDs/RBAC/Operator.
  - Attend l’état **Established** des CRDs.
  - **Pass 2** : rend/assure le **CR IBMLicensing** + Services.
  - Attend Deployments **Available** (`operator` puis `service-instance`).
  - Crée/assure la **Route TLS reencrypt** vers le service `ibm-licensing-service-instance:8080`.

### 10-uninstall.yml
- Rôle `uninstall` :
  - Supprime **CR IBMLicensing** (best effort).
  - Supprime Deployments, Services, Route du namespace `ns`.
  - Supprime **ClusterRole**/**ClusterRoleBinding** liés à ILS.
  - **Option** `purge_crds=true` : supprime les CRDs ILS.

### 20-audit.yml
- Vérifie prérequis (`oc`, `helm`), namespace, CRDs, Deployments, Services, Route.
- Récupère le **token** (`ibm-licensing-token`).
- Appelle **/version** et **/health?token=...** via la Route. Code **200** attendu.
- Port-forward **Prometheus** en local et lit **/metrics**.
- Exporte un **snapshot** via `/snapshot?token=...` (ou fallback `/api/v1/export`).
- Synthèse **OK/KO** en fin de run.

---

## Déploiement pas-à-pas
```bash
# 1) Installer les collections Ansible si besoin
make deps

# 2) Installer ILS
make install

# 3) Vérifier :
oc -n ibm-licensing get deploy,svc,route
HOST=$(oc -n ibm-licensing get route ibm-licensing-service-instance -o jsonpath='{.spec.host}')
curl -sk -o /dev/null -w '%{http_code}\n' "https://${HOST}/version"   # 200 attendu
TOK=$(oc -n ibm-licensing get secret ibm-licensing-token -o jsonpath='{.data.token}' | base64 -d)
curl -sk -o /dev/null -w '%{http_code}\n' "https://${HOST}/health?token=${TOK}" # 200 attendu
```

---

## Vérifications d’audit
```bash
make audit
```
Sortie attendue : codes 200 pour `/version`, `/health`, et **/metrics** OK. Un fichier de snapshot est écrit sous `playbooks/artifacts/`.

---

## Snapshot et métriques
Export **snapshot** manuel :
```bash
make snapshot
```

Lecture rapide des **métriques** Prometheus :
```bash
make metrics
```

---

## Désinstallation et purge
Désinstallation **standard** (conserve les CRDs) :
```bash
make uninstall
```

Purge **complète** (incluant CRDs) :
```bash
ansible-playbook -i inventories/hosts.yaml playbooks/10-uninstall.yml \
  -e "ns=ibm-licensing purge_crds=true"
```

---

## Notes de compatibilité
- Testé sur CRC/OpenShift local avec versions récentes de Kubernetes/OpenShift.
- Le rôle `install` est idempotent : relancer `make install` est **safe**.
- Les **Routes** OpenShift utilisent TLS **reencrypt** ; le service ILS écoute en **8080**.

---

## Sécurité et bonnes pratiques
- Le **token** `ibm-licensing-token` donne accès aux endpoints `/health` et `/snapshot`. Traiter ce secret comme **sensible**.
- Si vous utilisez l’**IBM Entitled Registry**, stocker la clé d’accès de façon sécurisée (SealedSecrets/External Secrets recommandé).
- Le répertoire `playbooks/artifacts/` peut contenir des **preuves d’installation** et des exports : versionner avec prudence.

---

## Dépannage
- **Boucle d’attente “Wait instance Deployment Available”** puis OK en fin de fenêtre : normal lors du premier bootstrap (création CRDs, Operator, puis Instance). L’attente est volontaire pour l’idempotence.
- **Port de la Route** : le service expose un port nommé parfois `api-port` targetPort `8080`. Le rôle `audit` accepte `api_service_port=8080` si l’auto-détection échoue.
- **PEP 668 / pip** : utiliser un virtualenv local `.venv` et pointer `ANSIBLE_PYTHON_INTERPRETER` si nécessaire.
- **CRDs déjà présentes** : les tâches sont “best-effort” et idempotentes. Les re-runs sont supportés.
- **Suppression incomplète** : utilisez `purge_crds=true` pour un reset total, puis relancez `make install`.

---

## CI/CD (optionnel)
- Ajouter une pipeline qui lance `make install` sur un cluster ephemeral, `make audit` pour l’évidence, et archive `playbooks/artifacts/`.
- GitOps : intégrer ces manifests/roles au flux Argo CD si vous basculez vers l’installation ILS par **Operator/OLM**.

---

## Licence
Ce dépôt fournit des scripts d’orchestration et d’automatisation. IBM License Service reste soumis aux licences IBM applicables.

