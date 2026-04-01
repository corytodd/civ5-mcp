IMAGE_NAME := ghcr.io/corytodd/civ5-mcp
PROJECT_ROOT := $(CURDIR)

default: build

DOCKER_RUN = docker run --rm -it \
				-v $(PROJECT_ROOT):/app \

.PHONY: .docker-run
.docker-run:
	$(DOCKER_RUN) --entrypoint $(ENTRYPOINT) $(IMAGE_NAME):latest $(ARGS)

.PHONY: docker-lint
docker-lint: ENTRYPOINT=make
docker-lint: ARGS=lint
docker-lint: .docker-run

.PHONY: docker-test
docker-test: ENTRYPOINT=make
docker-test: ARGS=test
docker-test: .docker-run

.PHONY: docker-build
docker-build: ENTRYPOINT=make
docker-build: ARGS=build
docker-build: .docker-run

.PHONY: lint test build
ifeq ($(OS),Windows_NT)
lint: docker-lint
test: docker-test
build: docker-build
else
lint:
	./tools/lint.sh
test:
	./tools/test.sh
build:
	./tools/build.sh
endif

.PHONY: clean
clean:
	rm -rf dist/

.PHONY: deploy
deploy: build
	pwsh tools/deploy.ps1

.PHONY: bump-version
bump-version:
	pwsh tools/bump-version.ps1
