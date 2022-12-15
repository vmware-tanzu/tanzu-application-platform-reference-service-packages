APP_NAME = $(shell cat config/config.yml | yq .app.name)
APP_VERSION = $(shell cat config/config.yml | yq .app.version)
DOCKER_REPO = "bzhtux"

.PHONY: docker-build-arm64 docker-push-arm64 docker-build-amd64 docker-push-amd64 help

docker-build-arm64: ## ⚆ Build arm64 docker image
	@echo "📦  Build ${APP_NAME} docker image: ${DOCKER_REPO}/${APP_NAME}-arm64:${APP_VERSION} for arm64"
	@docker buildx build . --platform linux/arm64 --tag ${DOCKER_REPO}/${APP_NAME}-arm64:${APP_VERSION}
	@echo "✓ Done"

docker-build-amd64: ## ⚆ Build amd64 docker image
	@echo "📦  Build ${APP_NAME} docker image: ${DOCKER_REPO}/${APP_NAME}-amd64:${APP_VERSION} for amd64"
	@docker buildx build . --platform linux/amd64 --tag ${DOCKER_REPO}/${APP_NAME}-amd64:${APP_VERSION}
	@echo "✓ Done"

docker-push-arm64: ## ⚆ Push arm64 docker image
	@echo "📦  Push ${DOCKER_REPO}/${APP_NAME}-arm64:${APP_VERSION} docker image"
	@docker push ${DOCKER_REPO}/${APP_NAME}-arm64:${APP_VERSION}
	@echo "✓ Done"

docker-push-amd64: ## ⚆ Push amd64 docker image
	@echo "📦  Push ${DOCKER_REPO}/${APP_NAME}-amd64:${APP_VERSION} docker image"
	@docker push ${DOCKER_REPO}/${APP_NAME}-amd64:${APP_VERSION}
	@echo "✓ Done"

.PHONY: help
help: ## ⚆ display this help message
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'


.DEFAULT_GOAL := help
