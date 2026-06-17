SHELL := /bin/bash
TF_DIR := terraform
ANSIBLE_DIR := ansible

.PHONY: help init plan apply deploy destroy ping test lint

help:
	@echo "Mini SOC - Makefile"
	@echo "  make init     - terraform init"
	@echo "  make plan     - terraform plan"
	@echo "  make apply    - terraform apply"
	@echo "  make deploy   - full deploy (TF + Ansible)"
	@echo "  make destroy  - terraform destroy"
	@echo "  make ping     - ansible connectivity check"
	@echo "  make test     - run detection tests"
	@echo "  make lint     - ansible syntax check"

init:
	cd $(TF_DIR) && terraform init

plan:
	cd $(TF_DIR) && terraform plan

apply:
	cd $(TF_DIR) && terraform apply -auto-approve

deploy: apply
	bash generate_inventory.sh
	cd $(ANSIBLE_DIR) && ansible-galaxy install -r requirements.yml
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/site.yml

destroy:
	cd $(TF_DIR) && terraform destroy -auto-approve

ping:
	cd $(ANSIBLE_DIR) && ansible all -m ping

test:
	bash docs/test_scenarios.sh

lint:
	cd $(ANSIBLE_DIR) && ansible-playbook --syntax-check playbooks/site.yml
