SHELL := /bin/bash
TF_DIR := terraform
ANSIBLE_DIR := ansible

.PHONY: help init plan apply deploy destroy status health clean test lint restart_logs init_security

help:
	@echo "Mini SOC (Docker) - Makefile"
	@echo ""
	@echo "  make init            - terraform init (Docker provider)"
	@echo "  make plan            - terraform plan"
	@echo "  make apply           - terraform apply"
	@echo "  make deploy          - apply + init_security + confirmation"
	@echo "  make init_security   - initialiser le plugin sécurité OpenSearch (1er démarrage)"
	@echo "  make configure       - Ansible : configurer les containers"
	@echo "  make status          - docker ps (containers SOC)"
	@echo "  make health          - vérifier la santé de la stack"
	@echo "  make destroy         - terraform destroy"
	@echo "  make clean      - destroy + supprimer les volumes"
	@echo "  make test       - lancer les scénarios de test"
	@echo "  make logs       - logs des containers"
	@echo ""

init:
	cd $(TF_DIR) && terraform init

plan:
	cd $(TF_DIR) && terraform plan

apply:
	cd $(TF_DIR) && terraform apply -auto-approve

deploy: apply init_security
	@echo ""
	@echo "Containers créés. Installation de community.docker..."
	cd $(ANSIBLE_DIR) && ansible-galaxy collection install community.docker
	@echo ""
	@echo "Configuration des containers (Ansible)..."
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/site.yml
	@echo ""
	@echo "SOC déployé ! Dashboard : http://localhost:443"
	@echo "  Login OpenSearch : admin / admin"
	@echo "  Login Wazuh API  : wazuh-wui / $(shell grep API_PASSWORD terraform/variables.tf 2>/dev/null | head -1 | sed 's/.*\"\(.*\)\".*/\1/' || echo "W4zuhS3cur3!2026")"
	@echo ""

init_security:
	@echo "Initialisation du plugin sécurité OpenSearch (securityadmin.sh)..."
	@sleep 5
	docker exec wazuh-indexer bash -c \
	  "JAVA_HOME=/usr/share/wazuh-indexer/jdk/ \
	  bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/securityadmin.sh \
	  -cd /usr/share/wazuh-indexer/config/opensearch-security/ \
	  -nhnv \
	  -cacert /usr/share/wazuh-indexer/config/certs/root-ca.pem \
	  -cert  /usr/share/wazuh-indexer/config/certs/admin.pem \
	  -key   /usr/share/wazuh-indexer/config/certs/admin-key.pem \
	  -p 9200"
	@echo "Sécurité OpenSearch initialisée."

configure:
	cd $(ANSIBLE_DIR) && ansible-galaxy collection install community.docker
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/site.yml

status:
	docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" --filter network=soc-network

health:
	@echo "=== Indexer ==="
	@curl -sfk -u admin:admin https://localhost:9200/_cluster/health 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "Not ready"
	@echo "=== Dashboard ==="
	@TOKEN=$$(curl -s -c - -X POST http://localhost:443/auth/login -H "osd-xsrf: true" -H "Content-Type: application/json" -d '{"username":"admin","password":"admin"}' 2>/dev/null | grep security_authentication | awk '{print $$NF}'); \
	if [ -n "$$TOKEN" ]; then \
	  curl -s -b "security_authentication=$$TOKEN" http://localhost:443/api/status 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print('Status:', d['status']['overall']['state'], '| Wazuh:', [s['state'] for s in d['status']['statuses'] if 'wazuh' in s['id']])" 2>/dev/null || echo "Dashboard API not ready"; \
	else \
	  echo "Dashboard auth failed"; \
	fi

destroy:
	cd $(TF_DIR) && terraform destroy -auto-approve

clean: destroy
	docker volume rm wazuh-indexer-data wazuh-manager-data wazuh-dashboard-data 2>/dev/null || true
	docker network rm soc-network 2>/dev/null || true

test:
	bash docs/test_scenarios.sh

logs:
	docker-compose logs --tail=50 -f 2>/dev/null || docker logs --tail=50 wazuh-indexer && docker logs --tail=50 wazuh-manager && docker logs --tail=50 wazuh-dashboard && docker logs --tail=50 wazuh-agent
