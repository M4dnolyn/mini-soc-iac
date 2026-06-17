# Mini SOC — Infrastructure as Code

> **Terraform · Docker · Wazuh**  
> Déploiement automatisé d'une plateforme SOC (Security Operations Center) en conteneurs Docker.

![Version](https://img.shields.io/badge/version-v2.0.0-blue)
![IaC](https://img.shields.io/badge/IaC-Terraform%201.5%2B-purple)
![Runtime](https://img.shields.io/badge/Runtime-Docker-blue)
![SIEM](https://img.shields.io/badge/SIEM-Wazuh-orange)

## Architecture

```
+------------------+   HTTPS :443    +---------------------------+
| Administrateur   | ──────────────▶ | wazuh-dashboard           |
| (navigateur)     |                 | Port 443 (localhost)      |
+------------------+                 +---------------------------+
                                              │
                                              │ OpenSearch :9200
                                              ▼
                                     +------------------+
                                     | wazuh-indexer    |
                                     | Port 9200        |
                                     +------------------+
                                              ▲
                                              │ Filebeat
                                     +------------------+
                                     | wazuh-manager    |
                                     | Ports 1514-1515  |
                                     | API :55000       |
                                     +------------------+
                                              ▲
                                              │ TCP :1514
                                     +------------------+
                                     | wazuh-agent      |
                                     | (client conteneur)|
                                     +------------------+
```

## Stack

| Technologie | Rôle | Version |
|-------------|------|---------|
| **Docker** | Runtime conteneurs | Latest |
| **Terraform** | Provisionnement IaC (provider Docker) | >= 1.5.0 |
| **Wazuh Indexer** | Stockage des alertes (OpenSearch) | 4.x |
| **Wazuh Manager** | Collecte et analyse des logs | 4.x |
| **Wazuh Dashboard** | Interface web de supervision | 4.x |
| **Wazuh Agent** | Agent de surveillance (conteneur) | 4.x |

## Prérequis

- Docker Engine installé et démarré
- Terraform >= 1.5.0

```bash
docker --version
terraform version
```

## Déploiement

```bash
git clone <repo>
cd mini-soc-iac
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
make deploy
```

### Accès au Dashboard

```text
URL      : http://localhost:443/app/wz-home
Login    : admin
Password : Admin123!
```

> **Note** : L'ancien chemin `/app/wazuh` n'existe plus dans Wazuh 4.x → utiliser `/app/wz-home`.
> Au 1er démarrage, un **health check** s'affiche : cliquer **Dismiss** pour accéder au dashboard.

### Vérification

```bash
make status    # docker ps des containers SOC
make health    # test santé Indexer + Dashboard
```

## Structure du dépôt

```
mini-soc-iac/
├── terraform/                  # IaC avec provider Docker
│   ├── versions.tf             # Provider kreuzwerker/docker
│   ├── variables.tf            # Variables (ports, versions, credentials)
│   ├── main.tf                 # Déclaration des containers Wazuh
│   ├── outputs.tf              # URLs et ports exposés
│   └── terraform.tfvars.example
├── ansible/                    # Optionnel — vérification / post-deploy
│   ├── ansible.cfg
│   ├── inventory.ini
│   └── playbooks/
│       ├── site.yml
│       ├── soc.yml
│       └── client.yml
├── docs/                       # Documentation et médias
├── Makefile                    # Commandes raccourcies
├── .gitignore
└── README.md
```

## Commandes

```bash
make init      # terraform init
make plan      # voir le plan
make apply     # créer les containers
make deploy    # apply + infos
make status    # docker ps
make health    # vérifier les services
make destroy   # supprimer les containers
make clean     # destroy + supprimer les volumes
```

## Cas d'usage de détection

| # | Scénario | Niveau |
|---|----------|--------|
| 1 | Brute force SSH (5+ échecs en 60s) | Medium |
| 2 | Création d'un utilisateur non autorisé | Medium |
| 3 | Modification de `/etc/passwd` (FIM) | High |

```bash
make test
```

## Version

- **V1** — 2 VMs libvirt/QEMU (archivée)
- **V2** — Wazuh en conteneurs Docker (actuelle)
