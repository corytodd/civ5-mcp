IMAGE_NAME := ghcr.io/corytodd/civ5-mcp
PROJECT_ROOT := $(CURDIR)

default: build

.PHONY: lint
lint:
	./tools/lint.sh

.PHONY: test
test:
	./tools/test.sh

.PHONY: build
build:
	./tools/build.sh

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
