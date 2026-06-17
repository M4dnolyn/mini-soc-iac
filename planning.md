# 📋 Planning — Mini SOC : Terraform · Ansible · Wazuh
> Infrastructure as Code | libvirt/QEMU | GitHub  
> Version V1 — Architecture de base

---

## ⏱️ Estimation globale du projet

| Niveau | Heures totales estimées |
|--------|------------------------|
| Débutant en DevOps/Linux | **50 à 65 heures** |
| Intermédiaire (Linux + Git OK) | **30 à 40 heures** |
| Avancé (Terraform/Ansible déjà pratiqués) | **15 à 25 heures** |

> **Recommandation réaliste pour un projet académique :** compter **35 à 45 heures** de travail effectif, réparties sur 3 à 4 semaines.

---

## 🗂️ Vue d'ensemble des phases

```
Phase 0 — Préparation & GitHub         (~3h)
Phase 1 — Environnement & Prérequis    (~4h)
Phase 2 — Infrastructure Terraform     (~8h)
Phase 3 — Configuration Ansible        (~8h)
Phase 4 — Déploiement Wazuh            (~6h)
Phase 5 — Cas d'usage & Tests          (~5h)
Phase 6 — Documentation & Finalisation (~5h)
                               TOTAL : ~39h
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
**Durée estimée : ~4 heures**

### Objectifs
- Installer et valider tous les outils nécessaires sur le poste hôte
- Configurer libvirt/QEMU en remplacement de VirtualBox

### Tâches

- [ ] Installer **libvirt**, **QEMU** et **virt-manager** sur le poste hôte :
  ```bash
  sudo apt install -y qemu-kvm libvirt-daemon-system virt-manager bridge-utils
  sudo usermod -aG libvirt $USER
  ```
- [ ] Vérifier que la virtualisation matérielle est activée (`egrep -c '(vmx|svm)' /proc/cpuinfo`)
- [ ] Installer **Terraform >= 1.5.0** et vérifier : `terraform version`
- [ ] Installer **Ansible >= 2.12** et vérifier : `ansible --version`
- [ ] Installer le provider Terraform pour libvirt (`dmacvicar/libvirt`) — différent du provider VirtualBox du document
- [ ] Générer une paire de clés SSH ED25519 : `ssh-keygen -t ed25519 -C "soc-project"`
- [ ] Télécharger l'image cloud Ubuntu Server 22.04 LTS (`.qcow2`) pour libvirt :
  ```bash
  wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
  ```
- [ ] Créer le réseau virtuel libvirt isolé (équivalent du réseau host-only VirtualBox) :
  ```bash
  virsh net-define soc-network.xml && virsh net-start soc-net
  ```
- [ ] Vérifier la connectivité réseau entre VMs avec `virsh list` et `virsh net-list`

### ⚠️ Point d'adaptation clé
> Le document source utilise le provider `terra-farm/virtualbox`. Avec libvirt/QEMU, on utilisera le provider **`dmacvicar/libvirt`** (officiel et maintenu). La syntaxe des ressources change : `libvirt_domain` remplace `virtualbox_vm`, et les images sont gérées via `libvirt_volume`.

### Livrable
> Environnement hôte 100% opérationnel, image Ubuntu cloud disponible, réseau libvirt configuré.

---

## Phase 2 — Infrastructure Terraform (libvirt)
**Durée estimée : ~8 heures**

### Objectifs
- Écrire le code Terraform pour provisionner VM-SOC et VM-CLIENT via libvirt/QEMU
- Maîtriser le cycle `init → plan → apply → destroy`

### Tâches

#### 2.1 — Fichier `versions.tf`
- [ ] Déclarer Terraform >= 1.5.0
- [ ] Déclarer le provider `dmacvicar/libvirt ~> 0.7.0`
- [ ] Configurer le provider libvirt avec l'URI locale : `qemu:///system`

#### 2.2 — Fichier `variables.tf`
- [ ] Déclarer les variables : noms des VMs, IPs, RAM, CPU, chemin image, clé SSH publique
- [ ] Créer `terraform.tfvars` avec les valeurs réelles (⚠️ à exclure du Git via `.gitignore`)

#### 2.3 — Fichier `main.tf`
- [ ] Créer le volume de base (image Ubuntu cloud) : ressource `libvirt_volume`
- [ ] Créer les volumes disques pour VM-SOC (30 Go) et VM-CLIENT (15 Go) par clonage
- [ ] Créer les disques cloud-init (`libvirt_cloudinit_disk`) pour injecter la clé SSH et le user `ansible`
- [ ] Déclarer la ressource `libvirt_domain` pour VM-SOC (2 vCPU, 6144 Mo RAM)
- [ ] Déclarer la ressource `libvirt_domain` pour VM-CLIENT (1 vCPU, 1024 Mo RAM)
- [ ] Attacher les VMs au réseau libvirt isolé avec les IPs statiques (`192.168.56.10` et `192.168.56.11`)

#### 2.4 — Fichier `outputs.tf`
- [ ] Exposer `soc_ip` et `client_ip` pour alimentation automatique de l'inventaire Ansible

#### 2.5 — Template `cloud-init.tpl`
- [ ] Définir le `user-data` : création utilisateur `ansible`, injection clé SSH, activation sudo sans mot de passe
- [ ] Définir le `network-config` : IPs statiques pour chaque VM

#### 2.6 — Script `generate_inventory.sh`
- [ ] Lire les outputs Terraform (`terraform output -json`)
- [ ] Générer automatiquement `ansible/inventory.ini` avec les IPs réelles

#### 2.7 — Validation
- [ ] `terraform init` → téléchargement du provider libvirt
- [ ] `terraform plan` → vérifier le plan (2 VMs, 2 volumes, 2 cloud-init)
- [ ] `terraform apply` → provisionner les VMs
- [ ] Tester la connexion SSH : `ssh ansible@192.168.56.10`
- [ ] Commit sur la branche `dev` + push GitHub

### Livrable
> 2 VMs Ubuntu accessibles en SSH, provisionnées par Terraform, code versionné sur GitHub.

---

## Phase 3 — Configuration Ansible
**Durée estimée : ~8 heures**

### Objectifs
- Structurer les playbooks et rôles Ansible
- Maîtriser l'inventaire, les group_vars et le cycle de déploiement

### Tâches

#### 3.1 — Configuration de base
- [ ] Rédiger `ansible/ansible.cfg` : définir le chemin de l'inventaire, désactiver la vérification host_key
- [ ] Générer `ansible/inventory.ini` via le script (ou manuellement pour les tests) :
  ```ini
  [soc]
  vm-soc ansible_host=192.168.56.10 ansible_user=ansible

  [clients]
  vm-client ansible_host=192.168.56.11 ansible_user=ansible

  [all:vars]
  ansible_ssh_private_key_file=~/.ssh/id_ed25519
  ansible_python_interpreter=/usr/bin/python3
  ```
- [ ] Tester la connectivité : `ansible all -m ping`

#### 3.2 — Variables de groupe
- [ ] Rédiger `group_vars/soc.yml` : version Wazuh, mot de passe admin, certificats TLS
- [ ] Rédiger `group_vars/clients.yml` : adresse IP du Manager, port 1514

#### 3.3 — Rôles Wazuh (Ansible Galaxy)
- [ ] Rédiger `requirements.yml` avec les 4 rôles officiels Wazuh
- [ ] Installer les rôles : `ansible-galaxy install -r requirements.yml`

#### 3.4 — Playbooks
- [ ] Rédiger `playbooks/site.yml` (orchestrateur principal)
- [ ] Rédiger `playbooks/soc.yml` (déploiement Wazuh Manager + Indexer + Dashboard)
- [ ] Rédiger `playbooks/client.yml` (déploiement Wazuh Agent)
- [ ] Configurer le template `ossec.conf` pour pointer l'agent vers `192.168.56.10:1514`

#### 3.5 — Validation syntaxique
- [ ] `ansible-playbook --syntax-check playbooks/site.yml`
- [ ] `ansible-playbook --check playbooks/site.yml` (dry-run)
- [ ] Commit sur `dev` + push GitHub

### Livrable
> Playbooks Ansible validés syntaxiquement, rôles installés, inventaire opérationnel.

---

## Phase 4 — Déploiement Wazuh
**Durée estimée : ~6 heures**

### Objectifs
- Déployer la suite Wazuh complète (Manager + Indexer + Dashboard + Agent)
- Vérifier que tous les services sont actifs et communicants

### Tâches

- [ ] Lancer le déploiement complet : `ansible-playbook playbooks/site.yml`
  > ⏳ Durée attendue : 15 à 30 minutes selon la machine hôte
- [ ] Vérifier les services sur VM-SOC :
  ```bash
  systemctl status wazuh-manager wazuh-indexer wazuh-dashboard
  ```
- [ ] Vérifier l'agent sur VM-CLIENT :
  ```bash
  systemctl status wazuh-agent
  ```
- [ ] Ouvrir le Dashboard : `https://192.168.56.10` et vérifier la connexion admin
- [ ] Vérifier que `vm-client` apparaît comme **Active** dans le Dashboard
- [ ] Vérifier les logs de communication Manager ↔ Indexer (port 9200)
- [ ] Corriger les erreurs éventuelles (certificats TLS, pare-feu UFW, mémoire insuffisante)
- [ ] Commit du rapport de déploiement dans `docs/` + push GitHub

### ⚠️ Points de vigilance
> - L'Indexer (OpenSearch) nécessite **au moins 4 Go de RAM** et peut mettre plusieurs minutes à démarrer.
> - Sous libvirt, vérifier que les règles `nftables`/`iptables` n'bloquent pas les ports 1514, 9200 et 443.
> - Le mot de passe admin est généré à l'installation — le noter immédiatement.

### Livrable
> SOC entièrement déployé, Dashboard accessible, agent connecté et actif.

---

## Phase 5 — Cas d'Usage & Tests de Détection
**Durée estimée : ~5 heures**

### Objectifs
- Valider les 3 cas d'usage de détection définis dans le projet
- Observer les alertes en temps réel dans le Dashboard

### Tâches

#### Cas 1 — Brute Force SSH (règle Wazuh 5712)
- [ ] Depuis le poste hôte, lancer 5+ tentatives SSH échouées vers VM-CLIENT :
  ```bash
  for i in {1..6}; do ssh root@192.168.56.11; done
  ```
- [ ] Observer l'alerte dans le Dashboard (niveau medium, source IP, timestamp)
- [ ] Capturer une screenshot dans `docs/screenshots/`

#### Cas 2 — Création d'un utilisateur non autorisé (règle 5902)
- [ ] Sur VM-CLIENT : `sudo useradd hacker`
- [ ] Observer l'alerte dans le Dashboard
- [ ] Capturer une screenshot

#### Cas 3 — Modification de `/etc/passwd` (File Integrity Monitoring)
- [ ] Sur VM-CLIENT : modifier `/etc/passwd` (ajouter une ligne commentée par exemple)
- [ ] Observer l'alerte FIM dans le Dashboard (rule 550, changes: size, md5, sha1)
- [ ] Capturer une screenshot

#### Automatisation des tests
- [ ] Créer un script `docs/test_scenarios.sh` qui reproduit les 3 cas automatiquement
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
- [ ] Documenter les différences **VirtualBox → libvirt/QEMU** dans `docs/adaptation_libvirt.md`

#### Makefile final
- [ ] Ajouter les cibles : `deploy`, `destroy`, `test`, `ping`, `lint`
  ```makefile
  deploy:
      cd terraform && terraform init && terraform apply -auto-approve
      bash generate_inventory.sh
      cd ansible && ansible-galaxy install -r requirements.yml
      cd ansible && ansible-playbook playbooks/site.yml

  destroy:
      cd terraform && terraform destroy -auto-approve

  ping:
      cd ansible && ansible all -m ping

  test:
      bash docs/test_scenarios.sh
  ```

#### GitHub — Finalisation
- [ ] Merger la branche `dev` dans `main` via Pull Request
- [ ] Créer un **tag de release** : `git tag v1.0.0 && git push --tags`
- [ ] Ajouter les **topics GitHub** : `terraform`, `ansible`, `wazuh`, `soc`, `libvirt`, `devops`, `cybersecurity`
- [ ] Vérifier que le `.gitignore` exclut bien tous les fichiers sensibles
- [ ] Relecture finale du README depuis un compte GitHub tiers (ou en navigation privée)

### Livrable
> Dépôt GitHub propre, documenté, taggé v1.0.0, prêt à être présenté ou partagé.

---

## 📅 Planning Semaine par Semaine (sur 4 semaines)

| Semaine | Phases | Heures |
|---------|--------|--------|
| **Semaine 1** | Phase 0 (GitHub) + Phase 1 (Environnement) + Phase 2 (Terraform) | ~10h |
| **Semaine 2** | Phase 3 (Ansible) + début Phase 4 (Déploiement) | ~10h |
| **Semaine 3** | Fin Phase 4 + Phase 5 (Tests & Détection) | ~8h |
| **Semaine 4** | Phase 6 (Documentation & Finalisation) | ~6h |
| **Total** | | **~34 à 39h** |

---

## 🔁 Commandes de référence rapide

```bash
# === TERRAFORM ===
terraform init          # Initialiser + télécharger provider libvirt
terraform plan          # Voir ce qui sera créé
terraform apply         # Provisionner les VMs
terraform destroy       # Supprimer toutes les ressources
terraform output -json  # Lire les IPs pour Ansible

# === ANSIBLE ===
ansible all -m ping                              # Tester la connectivité SSH
ansible-galaxy install -r requirements.yml       # Installer les rôles Wazuh
ansible-playbook playbooks/site.yml              # Déployer tout le SOC
ansible-playbook playbooks/site.yml --check      # Dry-run

# === LIBVIRT ===
virsh list --all         # Lister les VMs
virsh net-list           # Lister les réseaux
virsh console vm-soc     # Accès console VM (si SSH KO)

# === GIT ===
git checkout -b dev      # Travailler sur la branche dev
git add . && git commit -m "feat: ..."
git push origin dev
git tag v1.0.0 && git push --tags
```

---

## ⚡ Adaptation VirtualBox → libvirt/QEMU — Résumé des changements

| Élément | VirtualBox (document original) | libvirt/QEMU (ce projet) |
|---------|-------------------------------|--------------------------|
| Provider Terraform | `terra-farm/virtualbox ~> 0.2.0` | `dmacvicar/libvirt ~> 0.7.0` |
| Ressource VM | `virtualbox_vm` | `libvirt_domain` |
| Image disque | ISO Ubuntu Server | Image cloud `.qcow2` (Ubuntu Cloud) |
| Réseau isolé | Host-only `vboxnet0` | Réseau libvirt NAT ou isolé |
| Cloud-init | `user_data = templatefile(...)` | `libvirt_cloudinit_disk` |
| Gestion volumes | Intégrée à la VM | `libvirt_volume` séparé |
| URI provider | N/A | `qemu:///system` |

---

*Planning généré pour le projet Mini SOC — V1 | libvirt/QEMU | GitHub*