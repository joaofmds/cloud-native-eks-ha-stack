TF_ENV ?= dev
TF_DIR := infra/terraform/envs/$(TF_ENV)
TF_INIT_FLAGS ?= -input=false
TF_PLAN_FLAGS ?=

HELMFILE_ENV ?= default
HELMFILE_FILE ?= apps/helmfile.yaml

K6_SCRIPT ?= k6/stress.js
K6_FLAGS ?=

.PHONY: infra-plan apps-apply k6-stress

infra-plan:
	terraform -chdir=$(TF_DIR) init $(TF_INIT_FLAGS)
	terraform -chdir=$(TF_DIR) plan $(TF_PLAN_FLAGS)

apps-apply:
	HELMFILE_ENVIRONMENT=$(HELMFILE_ENV) helmfile -f $(HELMFILE_FILE) --environment $(HELMFILE_ENV) apply

k6-stress:
	@if [ -f $(K6_SCRIPT) ]; then \
		k6 run $(K6_FLAGS) $(K6_SCRIPT); \
	else \
		echo "Missing k6 script: $(K6_SCRIPT)" >&2; \
		exit 1; \
	fi
