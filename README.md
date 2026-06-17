# 🛡️ Mini SOC — Infrastructure as Code

> **Terraform · Ansible · Wazuh · libvirt/QEMU**  
> Déploiement automatisé d'une plateforme SOC (Security Operations Center) sur machines virtuelles locales.

![Version](https://img.shields.io/badge/version-v1.0.0-blue)
![IaC](https://img.shields.io/badge/IaC-Terraform%201.5%2B-purple)
![Config](https://img.shields.io/badge/Config-Ansible%202.12%2B-red)
![SIEM](https://img.shields.io/badge/SIEM-Wazuh-orange)
![OS](https://img.shields.io/badge/OS-Ubuntu%2022.04%20LTS-green)
![Hyperviseur](https://img.shields.io/badge/Hyperviseur-libvirt%2FQEMU-yellow)

---

## 📖 Description

Ce projet déploie un **Mini Security Operations Center (SOC)** entièrement automatisé grâce aux principes de l'Infrastructure as Code (IaC). Il constitue un support pédagogique couvrant à la fois la **cybersécurité défensive** et les pratiques **DevOps modernes**.

L'infrastructure repose sur deux machines virtuelles KVM/QEMU provisionnées par **Terraform** et configurées par **Ansible** :

- **VM-SOC** (`192.168.100.10`) — Héberge la suite complète Wazuh (Manager + Indexer + Dashboard)
- **VM-CLIENT** (`192.168.100.11`) — Machine surveillée, exécutant l'agent Wazuh

---

## 🏗️ Architecture

```
+------------------+        HTTPS :443         +---------------------------+
| Administrateur   | ─────────────────────────▶ | VM-SOC (192.168.100.10)  |
| (navigateur)     |                            | • Wazuh Manager           |
+------------------+                            | • Wazuh Indexer           |
                                                | • Wazuh Dashboard         |
                                                +---------------------------+
                                                          ▲
                                                TLS :1514 │ (logs chiffrés)
                                                          │
                                          +------------------------------+
                                          | VM-CLIENT (192.168.100.11)  |
                                          | • Ubuntu Server 22.04        |
                                          | • Wazuh Agent                |
                                          +------------------------------+
```

### Flux réseau

| Flux | Source | Destination | Port | Protocole |
|------|--------|-------------|------|-----------|
| Logs agents | VM-CLIENT | VM-SOC | 1514 | TCP/TLS |
| Indexation | Wazuh Manager | Wazuh Indexer | 9200 | TCP |
| Dashboard | Hôte (navigateur) | VM-SOC | 443 | HTTPS |

---

## 🔧 Stack Technologique

| Technologie | Rôle | Version |
|-------------|------|---------|
| **libvirt/QEMU** | Hyperviseur local (KVM) | 8.x+ |
| **Ubuntu Server 22.04 LTS** | OS des VMs (image cloud `.qcow2`) | 22.04 |
| **Terraform** | Provisionnement IaC des VMs | >= 1.5.0 |
| **Ansible** | Configuration automatisée | >= 2.12 |
| **Wazuh** | SIEM — collecte, analyse, alertes | 4.x |
| **Wazuh Indexer** | Stockage des alertes (OpenSearch) | 4.x |
| **Wazuh Dashboard** | Interface web de supervision | 4.x |
| **Git** | Versioning du code IaC | — |

---

## 📋 Prérequis

### Matériel (poste hôte)
- CPU avec virtualisation matérielle activée (Intel VT-x ou AMD-V)
- **16 Go de RAM minimum** (6 Go VM-SOC + 2 Go VM-CLIENT + OS hôte)
- 50 Go d'espace disque libre

### Logiciels
```bash
# Vérifier la virtualisation matérielle
egrep -c '(vmx|svm)' /proc/cpuinfo   # résultat > 0 requis

# Installer libvirt/QEMU (Debian/Ubuntu)
sudo apt install -y qemu-kvm libvirt-daemon-system virt-manager bridge-utils
sudo usermod -aG libvirt $USER
newgrp libvirt   # ⚠️ ou fermer/rouvrir la session pour prise en compte

# Terraform >= 1.5.0
terraform version

# Ansible >= 2.12
ansible --version
```

### Clé SSH
```bash
# Générer une paire de clés dédiée au projet
ssh-keygen -t ed25519 -C "mini-soc-iac" -f ~/.ssh/id_ed25519_soc
```

---

## 🚀 Déploiement rapide

### Option A — Commande unique (Makefile)
```bash
git clone https://github.com/M4dnolyn/mini-soc-iac.git
cd mini-soc-iac
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Éditer terraform.tfvars avec vos valeurs
make deploy
```

### Option B — Étape par étape

```bash
# 1. Provisionner les VMs avec Terraform
cd terraform/
terraform init
terraform plan
terraform apply

# 2. Générer l'inventaire Ansible depuis les outputs Terraform
cd ..
bash generate_inventory.sh

# 3. Installer les rôles Wazuh officiels
cd ansible/
ansible-galaxy install -r requirements.yml

# 4. Vérifier la connectivité SSH
ansible all -m ping

# 5. Déployer Wazuh sur toutes les machines
ansible-playbook playbooks/site.yml
```

### Accès au Dashboard
```
URL      : https://192.168.100.10
Login    : admin
Password : (généré à l'installation — voir ci-dessous)
```

#### Récupérer le mot de passe admin Wazuh

Le mot de passe est généré automatiquement à l'installation. Pour le récupérer sur VM-SOC :

```bash
# Sur la VM-SOC, après le déploiement Ansible :
sudo cat /etc/wazuh-indexer/internal_users.yml | grep -A1 admin
# ou :
sudo bash /var/ossec/scripts/wazuh-passwords-tool.sh -a
```

---

## 🔍 Cas d'usage de détection

| # | Scénario | Règle Wazuh | Niveau |
|---|----------|-------------|--------|
| 1 | Brute force SSH (5+ échecs en 60s) | 5712 | Medium |
| 2 | Création d'un utilisateur non autorisé | 5902 | Medium |
| 3 | Modification de `/etc/passwd` (FIM) | 550 | High |

```bash
# Tester les 3 scénarios automatiquement
make test
# ou
bash docs/test_scenarios.sh
```

---

## 📁 Structure du dépôt

```
mini-soc-iac/
│
├── terraform/                  # Provisionnement IaC (libvirt/QEMU)
│   ├── versions.tf             # Provider dmacvicar/libvirt
│   ├── variables.tf            # Variables d'infrastructure
│   ├── main.tf                 # Déclaration des VMs et volumes
│   ├── outputs.tf              # IPs exposées pour Ansible
│   ├── terraform.tfvars.example # Template des variables (à copier)
│   └── cloud-init.tpl          # Injection clé SSH + user ansible
│
├── ansible/                    # Configuration as Code
│   ├── ansible.cfg             # Configuration Ansible
│   ├── inventory.ini           # Inventaire (généré par Terraform)
│   ├── requirements.yml        # Rôles Wazuh officiels (Galaxy)
│   ├── group_vars/
│   │   ├── soc.yml             # Variables du serveur SOC
│   │   └── clients.yml         # Variables des machines clientes
│   └── playbooks/
│       ├── site.yml            # Playbook orchestrateur principal
│       ├── soc.yml             # Déploiement SOC (Manager+Indexer+Dashboard)
│       └── client.yml          # Déploiement agent Wazuh
│
├── docs/                       # Documentation et médias
│   ├── architecture.md         # Schéma d'architecture détaillé
│   ├── troubleshooting.md      # Erreurs fréquentes et solutions
│   ├── adaptation_libvirt.md   # Différences VirtualBox → libvirt
│   ├── test_scenarios.sh       # Script de test des cas d'usage
│   ├── screenshots/            # Captures du Dashboard Wazuh
│   └── diagrams/               # Schémas d'architecture
│
├── generate_inventory.sh       # Script : Terraform outputs → inventory.ini
├── Makefile                    # Commandes raccourcies (deploy, destroy, test)
├── .gitignore                  # Exclusions Git (secrets, état Terraform)
└── README.md                   # Ce fichier
```

---

## 🗑️ Destruction de l'infrastructure

```bash
make destroy
# ou
cd terraform/ && terraform destroy
```

---

## 🗺️ Feuille de route

- [x] **V1** — 2 VMs : SOC + 1 client Linux (architecture de base)
- [ ] **V2** — Ajout d'un 2ème client Linux (centralisation multi-sources)
- [ ] **V3** — Ajout d'un client Windows (hétérogénéité des OS)
- [ ] **V4** — Intégration Suricata (détection réseau NIDS)
- [ ] **V5** — TheHive + Cortex (gestion d'incidents)
- [ ] **V6** — Grafana (supervision 360°)

---

## 📚 Ressources

- [Documentation Wazuh](https://documentation.wazuh.com)
- [Provider Terraform libvirt](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs)
- [Ansible Galaxy — Rôles Wazuh](https://galaxy.ansible.com/wazuh)
- [Ubuntu Cloud Images](https://cloud-images.ubuntu.com/)

---

## 👤 Auteur

**M4dnolyn** — *Projet DevOps / Cybersécurité*

- GitHub : [@M4dnolyn](https://github.com/M4dnolyn)

---

## 📄 Licence

Projet académique — Usage pédagogique libre.