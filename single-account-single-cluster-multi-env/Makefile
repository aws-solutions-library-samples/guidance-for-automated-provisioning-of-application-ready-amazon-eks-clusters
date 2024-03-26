.ONESHELL:
SHELL = bash -o pipefail

ENVIRONMENT ?= dev
AWS_REGION ?= $(shell aws configure get region)
AWS_ACCOUNT_ID ?= $(shell aws sts get-caller-identity --output json | jq -r '.Account')
TFSTATE_S3_BUCKET ?= "tfstate-$(AWS_ACCOUNT_ID)"
TFSTATE_DDB_TABLE ?= "tfstate-lock"
VAR_FILE := $(CURDIR)/00.global/vars/$(ENVIRONMENT).tfvars

MODULES = $(shell find . -type f -name "backend.tf" -exec dirname {} \; | sort -u )

ifeq ($(AUTO_APPROVE), true)
	TF_AUTO_APPROVE := "-auto-approve"
else
	TF_AUTO_APPROVE := ""
endif

.PHONY: print-modules clean check-env bootstrap init-all plan-all apply-all destroy-all init plan apply destroy

print-modules:
	@for m in $(MODULES); do echo $$m; done

clean:
	@find . -type d -name ".terraform" -prune -exec rm -rf {} \;
	@find . -type f -name ".terraform.lock.hcl" -prune -exec rm -f {} \;

check-env:
	@if [ -z $(AWS_REGION) ]; then \
		echo "AWS_REGION was not set."; \
		exit 1; \
	 fi
	@if [ -z $(AWS_PROFILE) ]; then \
		echo "AWS_PROFILE was not set."; \
		exit 1; \
	 fi
	@if [ ! -f $(VAR_FILE) ]; then \
  		echo "VAR_FILE: $(VAR_FILE) does not exist."; \
  	fi
	@mkdir -p tf-logs

bootstrap: check-env
	@terraform -chdir=./00.tf-base init \
		-input=false \
		-upgrade \
		2>&1 | tee -a tf-logs/bootstrap-init.log
	@terraform -chdir=./00.tf-base apply \
		-no-color \
		-auto-approve \
		2>&1 | tee -a tf-logs/bootstrap-apply.log

init-all:
	@for m in $(MODULES); do \
  		$(MAKE) init MODULE=$$m || exit 1; \
  	done

plan-all:
	@for m in $(MODULES); do \
  		$(MAKE) plan MODULE=$$m || exit 1; \
  	done

apply-all:
	@for m in $(MODULES); do \
  		$(MAKE) apply MODULE=$$m || exit 1; \
  	done

destroy-all: MODULES := $(shell find . -type f -name "backend.tf" -exec dirname {} \; | sort -r )
destroy-all:
	@for m in $(MODULES); do \
  		$(MAKE) destroy MODULE=$$m || exit 1; \
  	done


init: check-env
	@if [ -z $(MODULE) ]; then \
		echo "MODULE was not set."; \
		exit 1; \
	fi
	@rm -rf $(MODULE)/.terraform/*.tfstate
	@echo ENVIRONMENT=$(ENVIRONMENT) MODULE=$(MODULE) terraform::init
	@terraform -chdir=$(MODULE) init \
		-input=false \
		-upgrade \
		-backend=true \
		-backend-config="region=$(AWS_REGION)" \
		-backend-config="bucket=$(TFSTATE_S3_BUCKET)" \
		-backend-config="dynamodb_table=$(TFSTATE_DDB_TABLE)" \
		2>&1 | tee -a tf-logs/$(notdir $(MODULE))-init.log

tf-select-ws:
	@if [ -z $(MODULE) ]; then \
		echo "MODULE was not set."; \
		exit 1; \
	fi
	@echo ENVIRONMENT=$(ENVIRONMENT) MODULE=$(MODULE) Switching to Terraform workspace: $(ENVIRONMENT)
	@terraform -chdir=$(MODULE) workspace select -or-create=true $(ENVIRONMENT)

plan: init tf-select-ws
	@echo ENVIRONMENT=$(ENVIRONMENT) MODULE=$(MODULE) terraform::plan
	@terraform -chdir=$(MODULE) plan \
		-input=false \
		-lock=true \
		-var-file=$(VAR_FILE) \
		2>&1 | tee -a tf-logs/$(notdir $(MODULE))-plan.log

apply: init tf-select-ws
	@echo ENVIRONMENT=$(ENVIRONMENT) MODULE=$(MODULE) terraform::apply
	@terraform -chdir=$(MODULE) apply \
		-input=false \
		-lock=true \
		-var-file=$(VAR_FILE) \
		-auto-approve \
		2>&1 | tee -a tf-logs/$(notdir $(MODULE))-apply.log

destroy: init tf-select-ws
	@echo ENVIRONMENT=$(ENVIRONMENT) MODULE=$(MODULE) terraform::destroy
	@terraform -chdir=$(MODULE) destroy \
	$(TF_AUTO_APPROVE) \
	-input=false \
	-lock=true \
	-var-file=$(VAR_FILE) \
	2>&1 | tee -a tf-logs/$(notdir $(MODULE))-destroy.log