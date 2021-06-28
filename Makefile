# ==================================================================================== #
# HELPERS
# ==================================================================================== #

## help: print this help message
.PHONY: help
help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'

# ==================================================================================== #
# LOCAL
# ==================================================================================== #

## local/deploy: deploy locally using docker compose and tail logs
.PHONY: local/deploy
local/deploy:
	docker compose up

## local/smoke: validate the local docker compose deployment is functional
.PHONY: local/smoke
local/smoke:
	docker compose down \
		&& cd test \
		&& go mod tidy \
		&& go test -run TestLocalDockerComposeDeployment

## local/teardown: destroy the local environment
.PHONY: local/teardown
local/teardown:
	docker compose down --rmi local -v

# ==================================================================================== #
# DEV
# ==================================================================================== #

## dev/deploy: deploy the dev environment's infrastructure
.PHONY: dev/deploy
dev/deploy: dev/deploy/infra

## dev/deploy/infra: run terraform to provision the infrastructure
.PHONY: dev/deploy/infra
dev/deploy/infra:
	aws configure \
		&& cd terraform/live/dev \
		&& terraform init \
		&& terraform validate \
		&& terraform apply

## dev/deploy/app: use kubectl to deploy the app to the dev infrastructure
.PHONY: dev/deploy/app
dev/deploy/app:
	kubectl apply -k kubernetes/dev

## dev/smoke: validate the dev kubernetes deployment is functional
.PHONY: dev/smoke
dev/smoke:
	cd test \
		&& go mod tidy \
		&& go test -run TestDevelopmentKubernetesDeployment

## dev/teardown: destroy the application dev environment
.PHONY: dev/teardown
dev/teardown:
	cd terraform/live/dev \
		&& terraform destroy
