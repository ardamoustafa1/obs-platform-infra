SHELL := /usr/bin/env bash
ENVIRONMENT ?= dev

.PHONY: fmt validate init plan apply

fmt:
	terraform fmt -recursive

validate:
	./scripts/validate.sh

init:
	terraform -chdir=environments/$(ENVIRONMENT) init

plan:
	terraform -chdir=environments/$(ENVIRONMENT) plan -out=$(ENVIRONMENT).tfplan

apply:
	terraform -chdir=environments/$(ENVIRONMENT) apply $(ENVIRONMENT).tfplan

