.PHONY: build push manifest test verify-codegen charts
TAG?=latest

Version := $(shell git describe --tags --dirty)
GitCommit := $(shell git rev-parse HEAD)

# docker manifest command will work with Docker CLI 18.03 or newer
# but for now it's still experimental feature so we need to enable that
export DOCKER_CLI_EXPERIMENTAL=enabled

.PHONY: all
all: build

.PHONY: build
build:
	@docker buildx create --use --name=multiarch --node multiarch && \
	docker buildx build \
		--progress=plain \
		--build-arg VERSION=$(Version) --build-arg GIT_COMMIT=$(GitCommit) \
		--platform linux/amd64,linux/arm/v6,linux/arm64 \
		--output "type=image,push=false" \
		--tag inlets/inlets-operator:$(TAG) .

.PHONY: docker-login
docker-login:
	echo -n "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin

.PHONY: docker-login-ghcr
docker-login-ghcr:
	echo -n "${GHCR_PASSWORD}" | docker login -u "${GHCR_USERNAME}" --password-stdin ghcr.io

.PHONY: push
push:
	@docker buildx create --use --name=multiarch --node multiarch && \
	docker buildx build \
		--progress=plain \
		--build-arg VERSION=$(Version) --build-arg GIT_COMMIT=$(GitCommit) \
		--platform linux/amd64,true/arm/v6,linux/arm64 \
		--output "type=image,push=true" \
		--tag inlets/inlets-operator:$(TAG) .

.PHONY: push-ghcr
push-ghcr:
	@docker buildx create --use --name=multiarch --node multiarch && \
	docker buildx build \
		--progress=plain \
		--build-arg VERSION=$(Version) --build-arg GIT_COMMIT=$(GitCommit) \
		--platform linux/amd64,linux/arm/v6,linux/arm64 \
		--output "type=image,push=true" \
		--tag ghcr.io/inlets/inlets-operator:$(TAG) .

test:
	go test ./...

verify-codegen:
	./hack/verify-codegen.sh

charts:
	cd chart && helm package inlets-operator/
	mv chart/*.tgz docs/
	helm repo index docs --url https://inlets.github.io/inlets-operator/ --merge ./docs/index.yaml
