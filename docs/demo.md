# Plan de démonstration — Mini SOC (V2 Docker)

> Durée estimée : 20-25 minutes
> Format : Présentation orale avec terminal + navigateur

---

## Table des matières

1. [Introduction — qu'est-ce que Mini SOC ?](#1-introduction--2-min)
2. [Architecture technique](#2-architecture-technique--3-min)
3. [Terraform — le provisionnement IaC](#3-terraform--5-min)
4. [Ansible — la configuration post-déploiement](#4-ansible--3-min)
5. [Makefile — tout en 1 commande](#5-makefile--1-min)
6. [Démo live — la stack en action](#6-démo-live--les-conteneurs--3-min)
7. [Dashboard Wazuh — l'interface SIEM](#7-dashboard-wazuh--5-min)
8. [Scénarios de détection (bonus)](#8-scénarios-de-détection-bonus--3-min)
9. [Conclusion](#9-conclusion--1-min)

---

## 1. Introduction — (2 min)

### Qu'est-ce que Mini SOC ?

Un **Security Operations Center (SOC) miniaturisé**, entièrement automatisé via Infrastructure as Code (IaC). Il déploie la suite **Wazuh 4.14.5** (SIEM open-source) en conteneurs Docker.

### Pourquoi ce projet ?

| Objectif | Réponse |
|----------|---------|
| Apprendre IaC | Terraform + Ansible sur un cas concret |
| Comprendre un SIEM | Wazuh : collecte, analyse, alerte |
| Docker en pratique | 4 conteneurs interconnectés |
| Projet "prêt à montrer" | 2 commandes = SOC fonctionnel |

### Évolution V1 → V2

| | V1 — libvirt/QEMU | V2 — Docker (actuelle) |
|---|---|---|
| Ressources | 2 VMs (8 Go RAM) | 4 conteneurs (~4 Go RAM) |
| Temps déploiement | 15-30 min | 1-3 min |
| Outils requis | libvirt, QEMU, cloud-init, SSH | Docker Engine seulement |
| Complexité | Ansible Galaxy + SSH + certificats | `docker exec` uniquement |

### Public cible

Développeurs, DevOps, étudiants en cybersécurité. Connaissances de base en Linux/Docker suffisantes.

---

## 2. Architecture technique — (3 min)

### Schéma

```
┌─────────────────────────────────────────────────────────────┐
│                       Hôte local                              │
│                                                               │
│  ┌─────────────┐    ┌──────────────┐                          │
│  │ wazuh-indexer│◄───│ wazuh-manager │                         │
│  │ OpenSearch   │    │ Wazuh Manager │                         │
│  │ Port 9200    │    │ Ports 1514    │                         │
│  │              │    │       1515    │                         │
│  │              │    │ API 55000     │                         │
│  └──────┬───────┘    └──────┬───────┘                          │
│         │                    │                                  │
│         │ Filebeat (TLS)    │ TCP 1514                         │
│         │                    │                                  │
│  ┌──────┴───────┐    ┌──────┴───────┐                          │
│  │wazuh-dashboard│    │ wazuh-agent   │                         │
│  │Dashboards 2.19│    │ client-01     │                         │
│  │ Plugin Wazuh  │    │ Privileged    │                         │
│  │ Port 443      │    │               │                         │
│  └──────┬───────┘    └──────────────┘                          │
│         │                                                       │
└─────────┼───────────────────────────────────────────────────────┘
          │ http://localhost:443
          │ Login : admin / admin
     ┌────┴────┐
     │  Vous   │
     └─────────┘
```

### Les 4 conteneurs

| Conteneur | Image | Rôle | Ports | Stockage |
|-----------|-------|------|-------|----------|
| **wazuh-indexer** | `wazuh/wazuh-indexer:4.14.5` | Moteur de recherche OpenSearch + stockage des alertes | `9200` (API REST) | Volume `wazuh-indexer-data` |
| **wazuh-manager** | `wazuh/wazuh-manager:4.14.5` | Collecte des logs, analyse, génération d'alertes, API REST | `1514` (agents), `1515` (enregistrement), `55000` (API) | Volume `wazuh-manager-data` |
| **wazuh-dashboard** | `wazuh/wazuh-dashboard:4.14.5` | Interface web OpenSearch Dashboards + plugin Wazuh | `443` (HTTP) | Volume `wazuh-dashboard-data` + bind-mount `conf/opensearch_dashboards.yml` |
| **wazuh-agent** | `wazuh/wazuh-agent:4.14.5` | Agent de surveillance (mode privileged) | aucun (sortant vers manager:1514) | Aucun (éphémère) |

### Flux réseau

```
1. Agent → Manager : logs via TCP 1514 (TLS)
2. Manager → Indexer : alertes via Filebeat (HTTPS 9200)
3. Dashboard → Indexer : requêtes OpenSearch (HTTPS 9200)
4. Dashboard → Manager : API REST (HTTPS 55000)
5. Vous → Dashboard : HTTP 443 (navigateur)
```

---

## 3. Terraform — (5 min)

### Objectif

> Provisionner l'infrastructure : 1 réseau Docker, 4 images, 3 volumes, 4 conteneurs.

### Structure

```
terraform/
├── versions.tf             # Provider Docker ~> 3.0, Terraform >= 1.5
├── variables.tf            # 11 variables paramétrables
├── main.tf                 # 12 ressources Terraform (le cœur)
├── outputs.tf              # URLs et noms exposés après apply
└── terraform.tfvars.example # Template à copier en .tfvars
```

### `versions.tf` — le moteur

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}
provider "docker" {}
```

> **À dire :** *"On utilise le provider officiel kreuzwerker/docker. Aucune configuration spéciale : Docker se connecte au socket local."*

### `variables.tf` — la paramétrisation

```hcl
variable "wazuh_version" {
  default = "4.14.5"
}
variable "api_password" {
  sensitive = true
  default   = "W4zuhS3cur3!2026"
}
variable "agent_name" {
  default = "wazuh-agent"
}
```

> **À dire :** *"Tout est variable : version Wazuh, ports, mots de passe (marqués sensitive pour les cacher dans les logs Terraform), nom de l'agent."*

### `main.tf` — les 12 ressources

**Bloc network** (1 ressource) :

```hcl
resource "docker_network" "soc" {
  name = "soc-network"
}
```

> **À dire :** *"Un réseau bridge isolé en 172.22.0.0/16. Tous les conteneurs s'y connectent et se voient par leur nom."*

**Bloc images** (4 ressources) :

```hcl
resource "docker_image" "indexer" {
  name = "wazuh/wazuh-indexer:${var.wazuh_version}"
}
```

> **À dire :** *"On tire les 4 images officielles Wazuh 4.14.5. Docker les pull au premier apply."*

**Bloc volumes** (3 ressources) :

```hcl
resource "docker_volume" "indexer_data" {
  name = "wazuh-indexer-data"
}
```

> **À dire :** *"Les volumes persistent les données de l'indexer, du manager et du dashboard. Même après un destroy/recreate, les données sont conservées."*

**Bloc conteneur indexer** (la référence) :

```hcl
resource "docker_container" "indexer" {
  name  = "wazuh-indexer"
  image = docker_image.indexer.name

  networks_advanced {
    name = docker_network.soc.name
  }

  ports {
    internal = 9200
    external = var.indexer_port
  }

  volumes {
    volume_name    = docker_volume.indexer_data.name
    container_path = "/var/lib/wazuh-indexer"
  }

  env = [
    "INDEXER_PASSWORD=admin",
    "DISABLE_INSTALL_DEMO_CONFIG=false",
    "DISABLE_SECURITY_PLUGIN=false",
  ]

  healthcheck {
    test         = ["CMD", "curl", "-sfk", "-u", "admin:admin", "https://localhost:9200"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 10
    start_period = "60s"
  }

  restart = "unless-stopped"
}
```

> **À dire :**
> - *"L'indexer, c'est OpenSearch 2.19.5, le moteur de recherche qui stocke les alertes."*
> - *"On expose le port 9200, on monte le volume de données, on injecte les variables d'env."*
> - *"Le healthcheck vérifie toutes les 30s que l'API OpenSearch répond."*
> - *"`start_period = 60s` laisse le temps à OpenSearch de démarrer avant les vérifications."*
> - *"Notez `-u admin:admin` dans le healthcheck : obligatoire car OpenSearch Security bloque les requêtes anonymes."*

**Bloc conteneur manager** :

```hcl
resource "docker_container" "manager" {
  env = [
    "INDEXER_URL=https://wazuh-indexer:9200",
    "INDEXER_USERNAME=admin",
    "INDEXER_PASSWORD=admin",
    "FILEBEAT_SSL_VERIFY_MODE=disable",
    "API_USERNAME=${var.api_username}",
    "API_PASSWORD=${var.api_password}",
  ]
  depends_on = [docker_container.indexer]
}
```

> **À dire :**
> - *"Le manager est le cerveau : il reçoit les logs des agents via 1514, les analyse, et envoie les alertes à l'indexer."*
> - *"Il expose aussi l'API REST (55000) que le dashboard appelle."*
> - *"`depends_on` garantit que l'indexer est créé en premier."*

**Bloc conteneur dashboard** :

```hcl
resource "docker_container" "dashboard" {
  volumes {
    host_path      = abspath("${path.root}/../conf")
    container_path = "/usr/share/wazuh-dashboard/config"
  }
  env = [
    "OPENSEARCH_HOSTS=https://wazuh-indexer:9200",
    "OPENSEARCH_USERNAME=admin",
    "OPENSEARCH_PASSWORD=admin",
    "OPENSEARCH_SSL_VERIFICATION_MODE=none",
    "WAZUH_API_URL=https://wazuh-manager",
    "API_USERNAME=${var.api_username}",
    "API_PASSWORD=${var.api_password}",
  ]
}
```

> **À dire :**
> - *"Le dashboard, c'est l'interface web. Basé sur OpenSearch Dashboards 2.19.5 avec le plugin Wazuh 4.14.5."*
> - *"On bind-mount le dossier `conf/` qui contient `opensearch_dashboards.yml` — l'image officielle ne le génère pas, on doit le fournir."*
> - *"`OPENSEARCH_SSL_VERIFICATION_MODE=none` : on désactive la vérification SSL car les certificats sont auto-signés (démo)."*
> - *"`WAZUH_API_URL` + `API_PASSWORD` : le plugin Wazuh a besoin de ces infos pour se connecter à l'API du manager."*

**Bloc conteneur agent** :

```hcl
resource "docker_container" "agent" {
  hostname = "wazuh-agent"
  privileged = true
  env = [
    "WAZUH_MANAGER_IP=wazuh-manager",
    "WAZUH_MANAGER_PORT=1514",
    "WAZUH_AGENT_NAME=client-01",
  ]
}
```

> **À dire :**
> - *"L'agent est en mode `privileged` : ça lui permet de monitorer le host Docker lui-même."*
> - *"`WAZUH_MANAGER_IP=wazuh-manager` : il se connecte au manager via le nom DNS du réseau Docker."*
> - *"Pas de volume persistant : l'agent est éphémère, il se réenregistre au démarrage."*

### `outputs.tf` — ce qu'on récupère

```hcl
output "dashboard_url" {
  value = "https://localhost:${var.dashboard_port}"
}
output "containers" {
  value = [
    docker_container.indexer.name,
    docker_container.manager.name,
    docker_container.dashboard.name,
    docker_container.agent.name,
  ]
}
```

> **À dire :** *"Terraform expose les URLs, les noms des conteneurs et les ports. Utile pour l'intégration avec Ansible ou pour l'affichage après apply."*

---

## 4. Ansible — (3 min)

### Objectif

> Configurer et vérifier les conteneurs après leur création par Terraform.

### Structure

```
ansible/
├── ansible.cfg            # inventaire local, pas de host_key_checking
├── inventory.ini          # [local] localhost ansible_connection=local
├── requirements.yml       # collection community.docker
├── group_vars/
│   ├── soc.yml            # Variables SOC (noms containers, ports, credentials)
│   └── clients.yml        # Variables agent (nom, IP manager)
├── playbooks/
│   ├── site.yml           # Orchestrateur : tous les rôles
│   ├── soc.yml            # Stack seulement (sans agent)
│   └── client.yml         # Agent seulement
└── roles/
    ├── verify/             # 5 tâches
    ├── configure_indexer/  # 2 tâches
    ├── configure_manager/  # 4 tâches
    ├── configure_dashboard/ # 2 tâches
    └── configure_agent/    # 7 tâches
```

### Pourquoi Ansible alors que Terraform crée déjà les conteneurs ?

> **À dire :** *"Terraform provisionne l'infrastructure (réseau, images, volumes, conteneurs). Mais il ne peut pas exécuter de commandes dans les conteneurs. Ansible vient faire la configuration interne : initialiser la sécurité OpenSearch, vérifier que les services tournent, corriger les fichiers de configuration."*

### Rôle `verify` — les prérequis

```yaml
- name: "Vérifier que les containers Wazuh existent"
  community.docker.docker_container_info:
    name: "{{ item }}"
  loop:
    - wazuh-indexer
    - wazuh-manager
    - wazuh-dashboard
    - wazuh-agent

- name: "Initialiser la sécurité de l'indexer (securityadmin)"
  ansible.builtin.shell:
    cmd: |
      docker exec -e JAVA_HOME=/usr/share/wazuh-indexer/jdk wazuh-indexer bash -c '
        export CACERT=/usr/share/wazuh-indexer/config/certs/root-ca.pem
        /usr/share/wazuh-indexer/plugins/opensearch-security/tools/securityadmin.sh \
          -cd /usr/share/wazuh-indexer/config/opensearch-security/ \
          -nhnv -cacert $CACERT -cert $CERT -key $KEY -p 9200 -icl -rev
      '
```

> **À dire :**
> - *"`community.docker.docker_container_info` : ce module Ansible interroge l'API Docker pour vérifier que les 4 conteneurs existent et tournent."*
> - *"`securityadmin.sh` : c'est l'outil officiel d'OpenSearch Security qui initialise les users, rôles et permissions dans l'indexer. On doit passer `JAVA_HOME` car le conteneur n'a pas la commande `which` (bug connu de l'image)."*
> - *"Les options `-icl -rev` : `icl` = ignore les locks, `rev` = validate avant d'appliquer."*

### Rôle `configure_indexer` — santé du cluster

```yaml
- name: "Vérifier la santé de l'indexer"
  ansible.builtin.shell:
    cmd: "curl -sfk -u admin:admin https://localhost:9200/_cluster/health"
  register: health

- name: "Afficher le statut du cluster"
  ansible.builtin.debug:
    var: health.stdout_lines
```

> **À dire :** *"On vérifie que le cluster OpenSearch est `green`. Le flag `-u admin:admin` est obligatoire car OpenSearch Security est activé. Sans ça, on obtient une 401."*

### Rôle `configure_manager` — services Wazuh

```yaml
- name: "Vérifier que le manager répond"
  ansible.builtin.shell:
    cmd: "docker exec wazuh-manager /var/ossec/bin/wazuh-control status"
  register: manager_status
  failed_when: false

- name: "Vérifier les indices Wazuh dans l'indexer"
  ansible.builtin.shell:
    cmd: "curl -sfk -u admin:admin https://localhost:9200/_cat/indices"
```

> **À dire :**
> - *"`wazuh-control status` liste tous les démons du manager. Certains sont optionnels (clusterd, maild...) et peuvent être down en single-node. On met `failed_when: false` pour ne pas échouer sur ces services optionnels."*
> - *"Les démons importants (analysisd, remoted, execd, authd, apid) doivent être `running`."*

### Rôle `configure_dashboard` — interface web

```yaml
- name: "Attendre que le Dashboard réponde"
  ansible.builtin.shell:
    cmd: "docker exec wazuh-dashboard curl -s -o /dev/null -w '%{http_code}' http://localhost:443/api/status"
  register: dashboard_status
  retries: 15
  delay: 5
  until: dashboard_status.rc == 0
```

> **À dire :** *"On attend que le dashboard réponde sur `/api/status`. On retry jusqu'à 15 fois (5 secondes entre chaque). Ça laisse le temps à OpenSearch Dashboards de démarrer complètement."*

### Rôle `configure_agent` — l'étoile du Nord

```yaml
- name: "Corriger l'adresse du manager dans ossec.conf"
  ansible.builtin.shell:
    cmd: "docker exec wazuh-agent sed -i 's|<address></address>|<address>wazuh-manager</address>|g; s|<manager_address></manager_address>|<manager_address>wazuh-manager</manager_address>|g' /var/ossec/etc/ossec.conf"

- name: "Démarrer l'agent"
  ansible.builtin.shell:
    cmd: "docker exec wazuh-agent /var/ossec/bin/wazuh-control start"

- name: "Vérifier si l'agent est enregistré"
  ansible.builtin.shell:
    cmd: "docker exec wazuh-manager /var/ossec/bin/manage_agents -l"
```

> **À dire :**
> - *"Problème : l'image officielle Wazuh Agent laisse les balises `<address>` et `<manager_address>` vides dans `ossec.conf`. L'agent ne sait pas où se connecter."*
> - *"Solution : une commande `sed` injecte `wazuh-manager` dans ces balises vides."*
> - *"Ensuite on démarre l'agent avec `wazuh-control start`."*
> - *"Enfin on vérifie l'enregistrement côté manager avec `manage_agents -l`."*
> - *"Résultat attendu : `ID: 001, Name: client-01, IP: any, Active`."*

### `inventory.ini` — pourquoi localhost ?

```ini
[local]
localhost ansible_connection=local ansible_python_interpreter=/usr/bin/python3
```

> **À dire :** *"Contrairement à la V1 où Ansible se connectait en SSH aux VMs, ici tout est local : Ansible s'exécute sur le host et utilise `docker exec` pour agir dans les conteneurs. Pas de SSH, pas de clés, pas d'inventaire distant."*

---

## 5. Makefile — (1 min)

### Objectif

> Unifier Terraform + Ansible en 1 commande.

```makefile
deploy: apply
	terraform apply -auto-approve
	ansible-galaxy collection install community.docker
	ansible-playbook playbooks/site.yml

status:
	docker ps --format "table {{.Names}}\t{{.Status}\t{{.Ports}}" --filter network=soc-network

health:
	@echo "=== Indexer ==="
	curl -sfk -u admin:admin https://localhost:9200/_cluster/health | python3 -m json.tool
	@echo "=== Dashboard ==="
	@TOKEN=$$(curl -s -c - -X POST http://localhost:443/auth/login -H "osd-xsrf: true" -H "Content-Type: application/json" -d '{"username":"admin","password":"admin"}' 2>/dev/null | grep security_authentication | awk '{print $$NF}'); \
	curl -s -b "security_authentication=$$TOKEN" http://localhost:443/api/status | python3 -c "import sys,json; d=json.load(sys.stdin); print('Status:', d['status']['overall']['state'], '| Wazuh:', [s['state'] for s in d['status']['statuses'] if 'wazuh' in s['id']])"

clean: destroy
	docker volume rm wazuh-indexer-data wazuh-manager-data wazuh-dashboard-data
	docker network rm soc-network
```

> **À dire :**
> - *"`make deploy` : une seule commande qui lance Terraform puis Ansible."*
> - *"`make status` : alias pour `docker ps` filtré sur le réseau soc-network."*
> - *"`make health` : vérifie la santé de l'indexer (authentifié) ET du dashboard (login + cookie + API status). Affiche le statut global et celui des plugins Wazuh."*
> - *"`make clean` : destroy Terraform + suppression forcée des volumes et du réseau."*

---

## 6. Démo live — les conteneurs (3 min)

### Étape 1 — `make status`

```bash
$ make status
NAMES              STATUS                  PORTS
wazuh-indexer      Up 2 hours (healthy)    0.0.0.0:9200->9200/tcp
wazuh-manager      Up 2 hours              0.0.0.0:1514-1515,55000->55000/tcp
wazuh-dashboard    Up 2 hours              0.0.0.0:443->443/tcp
wazuh-agent        Up 2 hours
```

> **Pointer :**
> - *"4 conteneurs, tous `Up`. L'indexer est `healthy` (le healthcheck Terraform passe)."*
> - *"Les ports sont bindés sur l'hôte : 9200, 1514-1515, 55000, 443."*
> - *"Tous sont sur le réseau `soc-network`."*

### Étape 2 — `make health`

```bash
$ make health
=== Indexer ===
{
    "cluster_name": "wazuh-cluster",
    "status": "green",
    "number_of_nodes": 1,
    "active_shards_percent_as_number": 100.0
}
=== Dashboard ===
Status: green | Wazuh: ['green', 'green', 'green']
```

> **Pointer :**
> - *"Indexer : cluster `green`, 1 nœud, 100% des shards actifs."*
> - *"Dashboard : `green` avec les 3 plugins Wazuh en `green` (Wazuh Core, Check Updates, et Wazuh principal)."*

### Étape 3 — Agent enregistré

```bash
$ docker exec wazuh-manager /var/ossec/bin/agent_control -l

Wazuh agent_control. List of available agents:
   ID: 000, Name: wazuh-manager (server), IP: 127.0.0.1, Active/Local
   ID: 001, Name: client-01, IP: any, Active
```

> **Pointer :**
> - *"L'agent `client-01` (ID 001) est `Active`. Son IP est `any` car il se connecte via le réseau Docker interne."*
> - *"L'ID 000 est le manager lui-même (auto-enregistré)."*

### Étape 4 — Logs du manager

```bash
$ docker exec wazuh-manager /var/ossec/bin/wazuh-control status
wazuh-clusterd not running...    # Normal : mode single-node
wazuh-modulesd is running...
wazuh-monitord is running...
wazuh-logcollector is running...
wazuh-remoted is running...
wazuh-syscheckd is running...
wazuh-analysisd is running...
wazuh-maild not running...       # Normal : pas de mail configuré
wazuh-execd is running...
wazuh-db is running...
wazuh-authd is running...
wazuh-agentlessd not running...  # Normal : optionnel
wazuh-integratord not running... # Normal : optionnel
wazuh-dbd not running...         # Normal : optionnel
wazuh-csyslogd not running...    # Normal : optionnel
wazuh-apid is running...
```

> **Pointer :** *"10 démons essentiels tournent. Les 5 qui sont `not running` sont optionnels (cluster, mail, agentless, integration, DB externe, syslog). C'est normal en single-node."*

---

## 7. Dashboard Wazuh — (5 min)

### Étape 1 — Connexion

| Action | Résultat |
|--------|----------|
| Ouvrir `http://localhost:443` | Page de login OpenSearch Dashboards |
| Login : `admin`, Password : `admin` | Accès à la page d'accueil |

> **Pointer :** *"OpenSearch Dashboards avec son propre système d'authentification (OpenSearch Security). Les identifiants par défaut du mode démo : admin/admin."*

### Étape 2 — Page d'accueil

Widgets visibles :
- **Agents** : nombre d'agents connectés (1)
- **Événements** : nombre d'événements reçus
- **Alertes** : nombre d'alertes générées (par niveau)
- **Règles** : nombre de règles activées

> **Pointer :** *"La page d'accueil donne une vue d'ensemble de l'état du SOC."*

### Étape 3 — Menu Agents

Menu → **Agents** → Afficher la liste

| Colonne | Valeur |
|---------|--------|
| ID | 001 |
| Name | client-01 |
| IP | any |
| Status | Active |
| OS | Linux |
| Version | Wazuh 4.14.5 |
| Last keep alive | il y a quelques secondes |

> **Pointer :**
> - *"Cliquer sur l'agent → onglet `Inventory` : matériel, OS, logiciels détectés."*
> - *"Onglet `FIM` : fichiers surveillés par File Integrity Monitoring."*
> - *"Onglet `Policy` : règles de conformité actives."*

### Étape 4 — Menu Management → Status

Menu → **Management** → **Status**

État des services Wazuh côté manager :
- analysisd (analyse des logs) : running
- remoted (communication agents) : running
- execd (exécution de commandes) : running
- authd (enregistrement agents) : running
- apid (API REST) : running

> **Pointer :** *"Même liste que `wazuh-control status` mais dans l'interface. Permet de vérifier que tout tourne sans ouvrir le terminal."*

### Étape 5 — Menu Modules → Security Events

Menu → **Modules** → **Security Events**

> **Pointer :**
> - *"C'est le cœur du SIEM : tous les événements de sécurité en temps réel."*
> - *"Chaque ligne = un log analysé par le manager avec niveau de criticité."*
> - *"On peut filtrer par niveau, par agent, par règle."*

### Étape 6 — Menu Modules → FIM

Menu → **Modules** → **FIM** (File Integrity Monitoring)

> **Pointer :**
> - *"FIM surveille les modifications de fichiers critiques."*
> - *"Montrer qu'il y a des entrées pour `/etc/passwd`, `/etc/shadow`, etc."*
> - *"Chaque entrée montre : fichier modifié, date, ancien hash, nouveau hash."*

### Étape 7 — Menu Settings → API

Menu → **Settings** → **API**

```yaml
URL:      https://wazuh-manager
Port:     55000
Username: wazuh-wui
Password: ••••••••••••••••
Status:   Connected
```

> **Pointer :**
> - *"La configuration API est automatique via les variables d'env `WAZUH_API_URL`, `API_USERNAME`, `API_PASSWORD` dans le conteneur dashboard."*
> - *"L'utilisateur `wazuh-wui` est créé automatiquement par le manager au premier démarrage."*

### Étape 8 — OpenSearch Dashboards (bonus)

Menu burger (hamburger icon) → **Discover**

> **Pointer :** *"L'interface Discover d'OpenSearch Dashboards permet de faire des requêtes brutes sur les index OpenSearch. Ici on peut voir les logs non filtrés."*

---

## 8. Scénarios de détection — bonus (3 min)

### Scénario 1 — Brute force SSH

```bash
# Depuis le terminal, lancer 6 tentatives SSH échouées
for i in {1..6}; do ssh root@localhost; done
```

> **Pointer :** *"Aller dans Security Events → filtrer par `rule.id: 5712`. Voir apparaître les alertes de brute force avec la source IP et le timestamp."*

### Scénario 2 — Création d'utilisateur

```bash
sudo useradd hacker
```

> **Pointer :** *"Filtrer par `rule.id: 5902`. L'alerte remonte immédiatement grâce à la règle de détection d'ajout d'utilisateur."*

### Scénario 3 — FIM

```bash
echo "# test" | sudo tee -a /etc/passwd
```

> **Pointer :** *"Filtrer par `rule.id: 550`. L'alerte FIM montre le fichier modifié, les checksums md5/sha1 avant/après."*

---

## 9. Conclusion — (1 min)

### Synthèse

```
┌─────────────────────────────────────────────────────────┐
│                    Mini SOC V2                           │
├─────────────────────────────────────────────────────────┤
│  Terraform  →  12 ressources    →  4 conteneurs Docker  │
│  Ansible    →  5 rôles          →  configuration + check│
│  Makefile   →  1 commande       →  deploy complet       │
│  Dashboard  →  http://localhost →  SIEM fonctionnel     │
│  Cleanup    →  1 commande       →  tout supprimer       │
└─────────────────────────────────────────────────────────┘
```

### Questions potentielles et réponses

| Question | Réponse |
|----------|---------|
| *Pourquoi pas Docker Compose ?* | Le but est IaC avec Terraform. Docker Compose n'est pas un outil IaC (pas de plan, pas de state, pas de cycle de vie). |
| *Pourquoi Ansible en plus ?* | Terraform crée les conteneurs. Ansible exécute des commandes dedans (securityadmin, sed, wazuh-control). Deux outils complémentaires. |
| *C'est sécurisé pour la prod ?* | Non, c'est une démo. Les mots de passe sont en dur, SSL désactivé, mode démo. Pour la prod : vault, certificats, réseau isolé. |
| *Quelle est la différence avec la V1 ?* | V1 = 2 VMs libvirt (30 min, 8 Go). V2 = 4 conteneurs Docker (2 min, 4 Go). Même fonctionnalité, infrastructure beaucoup plus légère. |
| *Comment ajouter un 2e agent ?* | Copier le bloc `docker_container.agent`, changer le nom, et le tour est joué. |

### Pour aller plus loin

- Ajouter un agent Windows (image `wazuh/wazuh-agent:4.14.5-windows`)
- Intégrer TheHive pour la gestion d'incidents
- Ajouter une alerte email via le manager
- Passer en mode cluster (3 nœuds indexer)
- CI/CD : GitHub Actions qui lance `terraform plan` sur chaque PR

---

> Document généré pour la présentation du projet Mini SOC V2 — Juin 2026
