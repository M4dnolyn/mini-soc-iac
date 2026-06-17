# 📋 Planning — Mini SOC : Terraform · Docker · Wazuh
> Infrastructure as Code | Docker | GitHub  
> Version V2 — Architecture conteneurisée

---

## ⏱️ Estimation globale du projet

| Niveau | Heures totales estimées |
|--------|------------------------|
| Débutant en DevOps/Linux | **30 à 40 heures** |
| Intermédiaire (Linux + Git OK) | **15 à 25 heures** |
| Avancé (Terraform déjà pratiqué) | **8 à 15 heures** |

> **Recommandation réaliste :** compter **15 à 25 heures** de travail effectif, réparties sur 2 à 3 semaines. Le passage à Docker supprime la couche VM (libvirt, cloud-init, SSH, Ansible lourd).

---

## 🗂️ Vue d'ensemble des phases

```
Phase 0 — Préparation & GitHub         (~2h)
Phase 1 — Environnement & Prérequis    (~1h)
Phase 2 — Infrastructure Terraform     (~4h)
Phase 3 — Déploiement Wazuh (Docker)   (~2h)
Phase 4 — Cas d'usage & Tests          (~4h)
Phase 5 — Documentation & Finalisation (~4h)
                               TOTAL : ~17h
```

---

## Phase 0 — Préparation & Dépôt GitHub
**Durée estimée : ~3 heures**

### Objectifs
- Initialiser le dépôt GitHub avec une structure propre
- Définir les conventions du projet (branches, commits, .gitignore)

### Tâches

- [ ] Créer le dépôt GitHub `mini-soc-iac` (public ou privé)
- [ ] Initialiser avec un `README.md` décrivant le projet
- [ ] Créer la structure de dossiers initiale :
  ```
  mini-soc-iac/
  ├── terraform/
  ├── ansible/
  ├── docs/
  ├── .gitignore
  ├── Makefile
  └── README.md
  ```
- [ ] Rédiger le `.gitignore` (exclure `terraform.tfstate`, `.terraform/`, `*.tfvars`, `*.retry`)
- [ ] Créer les branches de travail : `main` (stable) et `dev` (développement)
- [ ] Rédiger un `README.md` complet : description, prérequis, étapes de déploiement
- [ ] Faire un premier commit initial et push sur `main`

### Livrable
> Dépôt GitHub fonctionnel, structuré et versionné, prêt à recevoir le code.

---

## Phase 1 — Environnement & Prérequis
**Durée estimée : ~1 heure**

### Objectifs
- Installer et valider les outils nécessaires (Docker + Terraform + Ansible)

### Tâches

- [ ] Vérifier que **Docker Engine** est installé et démarré :
  ```bash
  docker --version
  docker info
  ```
- [ ] Installer **Terraform >= 1.5.0** et vérifier : `terraform version`
- [ ] Installer **Ansible >= 2.12** et vérifier : `ansible --version`

### Livrable
> Docker, Terraform et Ansible prêts sur le poste hôte.

---

## Phase 2 — Infrastructure Terraform (Docker)
**Durée estimée : ~4 heures**

### Objectifs
- Écrire le code Terraform avec le provider `kreuzwerker/docker`
- Provisionner les containers Wazuh (indexer, manager, dashboard, agent)
- Maîtriser les ressources Docker dans Terraform

### Tâches

#### 2.1 — Fichier `versions.tf`
- [ ] Déclarer Terraform >= 1.5.0
- [ ] Déclarer le provider `kreuzwerker/docker ~> 3.0`
- [ ] Pas de configuration provider nécessaire (Docker socket local)

#### 2.2 — Fichier `variables.tf`
- [ ] Déclarer les variables : version Wazuh, ports, mots de passe, nom agent
- [ ] Créer `terraform.tfvars` (⚠️ à exclure du Git via `.gitignore`)

#### 2.3 — Fichier `main.tf`
- [ ] Créer le réseau Docker `soc-network` : ressource `docker_network`
- [ ] Déclarer les images Docker Wazuh : `docker_image`
- [ ] Déclarer les volumes persistants : `docker_volume` (indexer, manager, dashboard)
- [ ] Déclarer le container `wazuh-indexer` (OpenSearch) : port 9200, healthcheck
- [ ] Déclarer le container `wazuh-manager` : ports 1514-1515, API 55000
- [ ] Déclarer le container `wazuh-dashboard` : port 443
- [ ] Déclarer le container `wazuh-agent` : mode privilégié, connexion au manager
- [ ] Configurer les variables d'environnement de chaque container

#### 2.4 — Fichier `outputs.tf`
- [ ] Exposer les URLs et ports des services

#### 2.5 — Validation
- [ ] `terraform init` → téléchargement du provider Docker
- [ ] `terraform plan` → vérifier le plan (1 network, 4 images, 3 volumes, 4 containers)
- [ ] `terraform apply` → provisionner les containers
- [ ] Vérifier avec `docker ps` que tous les containers tournent
- [ ] Commit sur la branche `dev` + push GitHub

### Livrable
> 4 containers Wazuh opérationnels, réseau Docker isolé, volumes persistants.

---

## Phase 3 — Configuration Ansible (Docker)
**Durée estimée : ~2 heures**

### Objectifs
- Utiliser Ansible pour configurer et vérifier les containers Wazuh
- Utiliser le module `community.docker.docker_container_exec`

### Tâches

#### 3.1 — Configuration Ansible
- [ ] Rédiger `ansible/ansible.cfg` : inventaire local
- [ ] Rédiger `inventory.ini` : connexion locale
- [ ] Installer la collection : `ansible-galaxy collection install community.docker`

#### 3.2 — Rôles Ansible
- [ ] Rôle `verify` : vérifier que Docker est disponible et les containers existent
- [ ] Rôle `configure_indexer` : vérifier la santé du cluster OpenSearch
- [ ] Rôle `configure_manager` : statut des services Wazuh, connexion Filebeat→Indexer
- [ ] Rôle `configure_dashboard` : vérifier que le Dashboard répond
- [ ] Rôle `configure_agent` : vérifier l'enregistrement de l'agent

#### 3.3 — Playbooks
- [ ] Rédiger `playbooks/site.yml` : orchestrateur (tous les rôles)
- [ ] Rédiger `playbooks/soc.yml` : stack SOC uniquement
- [ ] Rédiger `playbooks/client.yml` : agent uniquement

#### 3.4 — Validation
- [ ] `ansible-playbook playbooks/site.yml --syntax-check`
- [ ] `ansible-playbook playbooks/site.yml` après `terraform apply`
- [ ] Commit sur `dev` + push GitHub

### Livrable
> Ansible configure et vérifie les containers Wazuh. SOC entièrement déployé, Dashboard accessible, agent connecté.

---

## Phase 4 — Tests d'intégration

### Objectifs
- Valider que la stack complète fonctionne

### Tâches

- [ ] Lancer le déploiement complet : `make deploy` (Terraform + Ansible)
  > ⏳ Durée attendue : 1 à 3 minutes (pulls d'images Docker)
- [ ] Vérifier les containers : `make status`
- [ ] Vérifier la santé : `make health`
- [ ] Ouvrir le Dashboard : `https://localhost` (admin / Admin123!)
- [ ] Vérifier que l'agent `client-01` apparaît comme **Active** dans le Dashboard
- [ ] Corriger les erreurs éventuelles

### Livrable
> SOC entièrement fonctionnel en conteneurs Docker.

---

## Phase 4 bis — Cas d'Usage & Tests de Détection
**Durée estimée : ~4 heures**

### Objectifs
- Valider les 3 cas d'usage de détection (l'agent surveille le host Docker)

### Tâches

#### Cas 1 — Brute Force SSH (règle Wazuh 5712)
- [ ] Lancer des tentatives SSH échouées depuis le host :
  ```bash
  for i in {1..6}; do ssh root@localhost; done
  ```
- [ ] Observer l'alerte dans le Dashboard (niveau medium, source IP, timestamp)
- [ ] Capturer une screenshot dans `docs/screenshots/`

#### Cas 2 — Création d'un utilisateur non autorisé (règle 5902)
- [ ] Sur le host : `sudo useradd hacker`
- [ ] Observer l'alerte dans le Dashboard
- [ ] Capturer une screenshot

#### Cas 3 — Modification de `/etc/passwd` (File Integrity Monitoring)
- [ ] Modifier `/etc/passwd` (ajouter une ligne commentée)
- [ ] Observer l'alerte FIM dans le Dashboard (rule 550)
- [ ] Capturer une screenshot

#### Automatisation des tests
- [ ] Créer un script `docs/test_scenarios.sh` qui reproduit les 3 cas
- [ ] Commit des screenshots et du script dans `docs/` + push GitHub

### Livrable
> 3 cas d'usage validés et documentés avec captures d'écran, script de test reproductible.

---

## Phase 6 — Documentation & Finalisation
**Durée estimée : ~5 heures**

### Objectifs
- Finaliser la documentation technique
- Nettoyer le dépôt GitHub et créer un Makefile complet

### Tâches

#### Documentation
- [ ] Compléter le `README.md` avec : architecture, prérequis, étapes de déploiement, cas d'usage
- [ ] Ajouter un schéma d'architecture dans `docs/architecture.md`
- [ ] Rédiger `docs/troubleshooting.md` : erreurs fréquentes rencontrées et solutions

#### Makefile final
- [ ] Ajouter les cibles : `deploy`, `destroy`, `status`, `health`, `configure`
  ```makefile
  deploy:
      cd terraform && terraform init && terraform apply -auto-approve
      cd ansible && ansible-galaxy collection install community.docker
      cd ansible && ansible-playbook playbooks/site.yml

  configure:
      cd ansible && ansible-playbook playbooks/site.yml

  destroy:
      cd terraform && terraform destroy -auto-approve

  status:
      docker ps --filter network=soc-network

  health:
      curl -sfk https://localhost:9200/_cluster/health
  ```

#### GitHub — Finalisation
- [ ] Merger la branche `dev` dans `main` via Pull Request
- [ ] Créer un **tag de release** : `git tag v2.0.0 && git push --tags`
- [ ] Ajouter les **topics GitHub** : `terraform`, `ansible`, `wazuh`, `soc`, `docker`, `devops`, `cybersecurity`
- [ ] Vérifier que le `.gitignore` exclut bien tous les fichiers sensibles
- [ ] Relecture finale du README depuis un compte GitHub tiers (ou en navigation privée)

### Livrable
> Dépôt GitHub propre, documenté, taggé v2.0.0, prêt à être présenté ou partagé.

---

## 📅 Planning Semaine par Semaine (sur 2-3 semaines)

| Semaine | Phases | Heures |
|---------|--------|--------|
| **Semaine 1** | Phase 0 (GitHub) + Phase 1 (Prérequis) + Phase 2 (Terraform Docker) | ~7h |
| **Semaine 2** | Phase 3 (Ansible Docker) + Phase 4 (Tests) | ~6h |
| **Semaine 3** | Phase 5 (Documentation & Finalisation) | ~4h |
| **Total** | | **~17h** |

---

## 🔁 Commandes de référence rapide

```bash
# === TERRAFORM (Docker) ===
terraform init          # Initialiser + télécharger provider docker
terraform plan          # Voir ce qui sera créé
terraform apply         # Créer les containers Wazuh
terraform destroy       # Supprimer tous les containers
terraform output        # Voir les URLs des services

# === ANSIBLE (Docker) ===
ansible-galaxy collection install community.docker
ansible-playbook playbooks/site.yml   # Configurer les containers
ansible-playbook playbooks/soc.yml    # Stack SOC uniquement
ansible-playbook playbooks/client.yml # Agent uniquement

# === DOCKER ===
docker ps --filter network=soc-network              # Lister les containers SOC
docker logs wazuh-manager --tail 50                  # Logs du manager
docker exec wazuh-manager /var/ossec/bin/wazuh-control status  # Statut interne

# === GIT ===
git checkout -b dev      # Travailler sur la branche dev
git add . && git commit -m "feat: ..."
git push origin dev
git tag v2.0.0 && git push --tags
```

---

## ⚡ Évolution des architectures

| Élément | V1 — VMs (libvirt) | V2 — Containers (Docker) |
|---------|-------------------|--------------------------|
| Provider Terraform | `dmacvicar/libvirt` | `kreuzwerker/docker` |
| Ressource principale | `libvirt_domain` | `docker_container` |
| OS invité | Ubuntu Server 22.04 cloud `.qcow2` | Images officielles Wazuh |
| Réseau | Réseau libvirt NAT | Réseau Docker bridge |
| Configuration VM | cloud-init (user-data + SSH keys) | Variables d'environnement |
| Agent de config | Ansible (via SSH) | Ansible (via `docker_container_exec`) |
| Stockage | Volumes libvirt (qcow2) | Volumes Docker |
| RAM requise | 8+ Go (2 VMs) | ~4 Go (containers) |
| Temps déploiement | 15-30 min | 1-3 min |
| Outils supplémentaires | libvirt, QEMU, xorriso, cloud-init | Docker Engine uniquement |

---

*Planning généré pour le projet Mini SOC — V2 | Docker | GitHub*