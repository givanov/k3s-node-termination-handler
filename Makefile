# Get current directory
DIR := ${CURDIR}

SOURCE_FILES?=./...
TEST_PATTERN?=.
TEST_OPTIONS?=
# reenable after this is fixed for go 1.13
TEST_COVERAGE_OPTIONS ?= # -coverpkg=./... -covermode=atomic -coverprofile=coverage.out
OS=$(shell uname -s)
GO        ?= go
BINDIR    := $(DIR)/bin
LDFLAGS   := -w -s

TARGETS   ?= darwin/amd64 linux/amd64 windows/amd64
DIST_DIRS = find * -type d -exec

SHELL = /bin/bash

BASE_BUILD_PATH = github.com/givanov/k3s-node-termination-handler
BUILD_PATH = $(BASE_BUILD_PATH)/cmd/manager
NAME = k3s-node-termination-handler

GIT_SHORT_COMMIT := $(shell git rev-parse --short HEAD)
GIT_TAG    := $(shell git describe --tags --abbrev=0 --exact-match 2>/dev/null)
HAS_GOX := $(shell command -v gox;)
HAS_GIT := $(shell command -v git;)
GIT_DIRTY  = $(shell test -n "`git status --porcelain`" && echo "dirty" || echo "clean")
HAS_GO_IMPORTS := $(shell command -v goimports;)
HAS_GO_MOCKGEN := $(shell command -v mockgen;)
HAS_GOLANGCI_LINT := $(shell command -v golangci-lint;)

GOLANGCI_LINT_VERSION := v1.24.0
GOLANGCI_VERSION_CHECK := $(shell golangci-lint --version | grep -oh $(GOLANGCI_LINT_VERSION);)

DOCKER_REPO := quay.io/givanov
DOCKER_IMAGE_NAME := k3s-node-termination-handler

TMP_VERSION := $(GIT_SHORT_COMMIT)

GCLOUD_KEY_FILE := /etc/google-service-account/service-account.json

ifndef VERSION
ifeq ($(GIT_DIRTY), clean)
ifdef GIT_TAG
	TMP_VERSION = $(GIT_TAG)
endif
endif
endif

VERSION ?= $(TMP_VERSION)

BINARY_VERSION ?= ${VERSION}

# Only set Version if building a tag or VERSION is set
ifneq ($(BINARY_VERSION),)
	LDFLAGS += -X $(BASE_BUILD_PATH)/version.Version=${BINARY_VERSION}
endif

.PHONY: setup-lint
setup-lint:
	@echo "bootstrap lint..."
ifndef HAS_GOLANGCI_LINT
	@echo "golangci-lint $(GOLANGCI_LINT_VERSION) not found..."
	@GOPROXY=direct GOSUMDB=off go get -u github.com/golangci/golangci-lint/cmd/golangci-lint@$(GOLANGCI_LINT_VERSION)
else
	@echo "golangci-lint found, checking version..."
ifeq ($(GOLANGCI_VERSION_CHECK), )
	@echo "found different version, installing golangci-lint $(GOLANGCI_LINT_VERSION)..."
	@GOPROXY=direct GOSUMDB=off go get -u github.com/golangci/golangci-lint/cmd/golangci-lint@$(GOLANGCI_LINT_VERSION)
else
	@echo "golangci-lint version $(GOLANGCI_VERSION_CHECK) found!"
endif
endif

# Install all the build and lint dependencies
.PHONY: setup
setup: setup-lint
ifndef HAS_GOX
	$(GO) get -u github.com/mitchellh/gox
endif
ifndef HAS_GO_IMPORTS
	$(GO) get golang.org/x/tools/cmd/goimports
endif
ifndef HAS_GO_MOCKGEN
	$(GO) get github.com/golang/mock/gomock
	$(GO) install github.com/golang/mock/mockgen
endif
	@which ./bin/openapi-gen > /dev/null || go build -o ./bin/openapi-gen k8s.io/kube-openapi/cmd/openapi-gen

test:
	$(GO) test $(TEST_OPTIONS) \
	-v -failfast \
	$(TEST_COVERAGE_OPTIONS) \
	$(SOURCE_FILES) \
	-run $(TEST_PATTERN) -timeout=2m

cover: test
	$(GO) tool cover -html=coverage.out

fmt:
	find . -name '*.go' -not -wholename './vendor/*' | while read -r file; do gofmt -w -s "$$file"; goimports -w "$$file"; done

lint:
	golangci-lint run \
	--enable-all \
	-D gochecknoglobals \
	-D gochecknoinits \
	-D dupl \
	--timeout 2m \
	./...

.DEFAULT_GOAL := build

info:
	@echo "How are you:       $(GIT_DIRTY)"
	@echo "Version:           ${VERSION}"
	@echo "Git Tag:           ${GIT_TAG}"
	@echo "Git Commit:        ${GIT_SHORT_COMMIT}"

.PHONY: build
build: build-cross

# usage: make clean build-cross dist VERSION=v0.2-alpha
.PHONY: build-cross
build-cross: LDFLAGS += -extldflags "-static"
build-cross:
	CGO_ENABLED=0 gox -parallel=3 -output="_dist/{{.OS}}-{{.Arch}}/{{.Dir}}/$(NAME)" -osarch='$(TARGETS)' -ldflags '$(LDFLAGS)' $(BUILD_PATH)

.PHONY: build-docker
build-docker: LDFLAGS += -extldflags "-static"
build-docker:
	CGO_ENABLED=0 go build -ldflags '$(LDFLAGS)' -o _dist/k3s-node-termination-handler $(BUILD_PATH)

.PHONY: dist
dist:
	( \
		cd _dist && \
		$(DIST_DIRS) tar -zcf $(NAME)-${VERSION}-{}.tar.gz {} \; && \
		$(DIST_DIRS) zip -r $(NAME)-${VERSION}-{}.zip {} \; \
	)

.PHONY: clean
clean: helm-clean
	@rm -rf $(BINDIR) ./_dist

.PHONY: generate
generate: setup
	@operator-sdk generate k8s
	@operator-sdk generate crds
	@./bin/openapi-gen --logtostderr=true \
	    -o "" \
	    -O zz_generated.openapi \
	    -h ./hack/boilerplate.go.txt -r "-"
	@go generate ./...

CHART_NAME ?= k3s-node-termination-handler
CHART_VERSION ?= 0.0.0
CHART_PATH ?= deploy/helm
CHART_DIST ?= $(CHART_PATH)/$(CHART_NAME)/dist
HELM_PLUGIN_PUSH_URL := https://github.com/chartmuseum/helm-push
HELM_PLUGIN_PUSH_VERSION := v0.8.1
HELM_REPO_URL := https://charts.ouzi.io
HELM_REPO_NAME := ouzi

.PHONY: helm-clean
helm-clean:
	rm -rf $(CHART_PATH)/$(CHART_NAME)/charts
	rm -rf $(CHART_DIST)

# does not work without explicitly specifying the api version
# see: https://github.com/helm/helm/issues/6505
.PHONY: helm-validate
helm-validate:
	helm template k3s-node-termination-handler \
	--namespace k3s-node-termination-handler \
	--debug \
	-a apiregistration.k8s.io/v1beta1 \
	-a cert-manager.io/v1alpha2 \
	-a monitoring.coreos.com/v1 \
	-a apiextensions.k8s.io/v1beta1 \
	$(CHART_PATH)/${CHART_NAME}

.PHONY: helm-package
helm-package: helm-clean
	@helm package \
	--version=$(VERSION) \
	--app-version=$(VERSION) \
	--dependency-update \
	--destination $(CHART_DIST) \
	$(CHART_PATH)/$(CHART_NAME)

.PHONY: helm-lint
helm-lint:
	helm lint $(CHART_PATH)/$(CHART_NAME)

.PHONY: export-tag-github-actions
export-tag-github-actions:
	@echo ::set-output name=output_msg::$(VERSION)

.PHONY: semantic-release
semantic-release:
	@npm ci
	@npx semantic-release

.PHONY: semantic-release-dry-run
semantic-release-dry-run:
	@npm ci
	@npx semantic-release -d

package-lock.json: package.json
	@npm install

.PHONY: install-npm-check-updates
install-npm-check-updates:
	npm install npm-check-updates

.PHONY: update-npm-dependencies
update-npm-dependencies: install-npm-check-updates
	ncu -u
	npm install

DOCKER_PLATFORMS ?= linux/arm,linux/arm64,linux/amd64,linux/ppc64le,linux/s390x
DOCKER_IMAGE_TAG ?= $(VERSION)
DOCKERFILE_PATH = build/Dockerfile
DOCKERBUILD_CONTEXT = .

.PHONY: docker-image-build-push
docker-image-build-push:
	DOCKER_CLI_EXPERIMENTAL=enabled docker buildx build -f $(DOCKERFILE_PATH) -t $(DOCKER_REPO)/$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG) --platform=$(DOCKER_PLATFORMS) . --push