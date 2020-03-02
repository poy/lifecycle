GOCMD?=go
GOFLAGS?=-mod=vendor
GOENV=GOARCH=amd64 CGO_ENABLED=0
LDFLAGS=-s -w
LDFLAGS+=-X 'github.com/buildpacks/lifecycle/cmd.Version=$(LIFECYCLE_VERSION)'
LDFLAGS+=-X 'github.com/buildpacks/lifecycle/cmd.SCMRepository=$(SCM_REPO)'
LDFLAGS+=-X 'github.com/buildpacks/lifecycle/cmd.SCMCommit=$(SCM_COMMIT)'
LDFLAGS+=-X 'github.com/buildpacks/lifecycle/cmd.PlatformAPI=$(PLATFORM_API)'
GOBUILD=$(GOCMD) build -ldflags "$(LDFLAGS)"
GOTEST=$(GOCMD) test
LIFECYCLE_VERSION?=0.0.0
PLATFORM_API?=0.3
BUILDPACK_API?=0.2
SCM_REPO?=
SCM_COMMIT?=$$(git rev-parse --short HEAD)
BUILD_DIR?=out

export GOFLAGS:=$(GOFLAGS)

define LIFECYCLE_DESCRIPTOR
[api]
  platform = "$(PLATFORM_API)"
  buildpack = "$(BUILDPACK_API)"

[lifecycle]
  version = "$(LIFECYCLE_VERSION)"
endef

all: test build package

build: build-linux build-windows

build-linux: export GOOS:=linux
build-linux: OUT_DIR:=$(BUILD_DIR)/$(GOOS)/lifecycle
build-linux:
	@echo "> Building for linux..."
	mkdir -p $(OUT_DIR)
	$(GOENV) $(GOBUILD) -o $(OUT_DIR) -a ./cmd/launcher
	$(GOENV) $(GOBUILD) -o $(OUT_DIR)/lifecycle -a ./cmd/lifecycle
	ln -sf lifecycle $(OUT_DIR)/detector
	ln -sf lifecycle $(OUT_DIR)/analyzer
	ln -sf lifecycle $(OUT_DIR)/restorer
	ln -sf lifecycle $(OUT_DIR)/builder
	ln -sf lifecycle $(OUT_DIR)/exporter
	ln -sf lifecycle $(OUT_DIR)/rebaser
	ln -sf lifecycle $(OUT_DIR)/creator

build-windows: export GOOS:=windows
build-windows: OUT_DIR:=$(BUILD_DIR)/$(GOOS)/lifecycle
build-windows:
	@echo "> Building for windows..."
	mkdir -p $(OUT_DIR)
	$(GOENV) $(GOBUILD) -o $(OUT_DIR) -a ./cmd/launcher
	$(GOENV) $(GOBUILD) -o $(OUT_DIR)/lifecycle.exe -a ./cmd/lifecycle
	ln -sf lifecycle.exe $(OUT_DIR)/analyzer.exe
	ln -sf lifecycle.exe $(OUT_DIR)/restorer.exe
	ln -sf lifecycle.exe $(OUT_DIR)/builder.exe
	ln -sf lifecycle.exe $(OUT_DIR)/exporter.exe
	ln -sf lifecycle.exe $(OUT_DIR)/rebaser.exe
	ln -sf lifecycle.exe $(OUT_DIR)/creator.exe

build-darwin: export GOOS:=darwin
build-darwin: OUT_DIR:=$(BUILD_DIR)/$(GOOS)/lifecycle
build-darwin:
	@echo "> Building for macos..."
	mkdir -p $(OUT_DIR)
	$(GOENV) $(GOBUILD) -o $(OUT_DIR) -a ./cmd/launcher
	$(GOENV) $(GOBUILD) -o $(OUT_DIR)/lifecycle -a ./cmd/lifecycle
	ln -sf lifecycle $(OUT_DIR)/detector
	ln -sf lifecycle $(OUT_DIR)/analyzer
	ln -sf lifecycle $(OUT_DIR)/restorer
	ln -sf lifecycle $(OUT_DIR)/builder
	ln -sf lifecycle $(OUT_DIR)/exporter
	ln -sf lifecycle $(OUT_DIR)/rebaser

install-goimports:
	@echo "> Installing goimports..."
	cd tools; $(GOCMD) install golang.org/x/tools/cmd/goimports

install-yj:
	@echo "> Installing yj..."
	cd tools; $(GOCMD) install github.com/sclevine/yj

install-mockgen:
	@echo "> Installing mockgen..."
	cd tools; $(GOCMD) install github.com/golang/mock/mockgen

install-golangci-lint:
	@echo "> Installing golangci-lint..."
	cd tools; $(GOCMD) install github.com/golangci/golangci-lint/cmd/golangci-lint

lint: install-golangci-lint
	@echo "> Linting code..."
	@golangci-lint run -c golangci.yaml

generate: install-mockgen
	@echo "> Generating..."
	$(GOCMD) generate

format: install-goimports
	@echo "> Formating code..."
	test -z $$(goimports -l -w -local github.com/buildpacks/lifecycle $$(find . -type f -name '*.go' -not -path "*/vendor/*"))

verify-jq:
ifeq (, $(shell which jq))
	$(error "No jq in $$PATH, please install jq")
endif

test: unit acceptance

unit: verify-jq format lint install-yj
	@echo "> Running unit tests..."
	$(GOTEST) -v -count=1 ./...

acceptance: format lint
	@echo "> Running acceptance tests..."
	$(GOTEST) -v -count=1 -tags=acceptance ./acceptance/...
	
acceptance-darwin: format lint
	@echo "> Running acceptance tests..."
	$(GOTEST) -v -count=1 -tags=acceptance ./acceptance/...

clean:
	@echo "> Cleaning workspace..."
	rm -rf $(BUILD_DIR)

package: package-linux package-windows

package-linux: export LIFECYCLE_DESCRIPTOR:=$(LIFECYCLE_DESCRIPTOR)
package-linux: GOOS:=linux
package-linux: GOOS_DIR:=$(BUILD_DIR)/$(GOOS)
package-linux: ARCHIVE_NAME=lifecycle-v$(LIFECYCLE_VERSION)+$(GOOS).x86-64
package-linux:
	@echo "> Writing descriptor file for $(GOOS)..."
	mkdir -p $(GOOS_DIR)
	echo "$${LIFECYCLE_DESCRIPTOR}" > $(GOOS_DIR)/lifecycle.toml

	@echo "> Packaging lifecycle for $(GOOS)..."
	tar czf $(BUILD_DIR)/$(ARCHIVE_NAME).tgz -C $(GOOS_DIR) lifecycle.toml lifecycle

package-windows: export LIFECYCLE_DESCRIPTOR:=$(LIFECYCLE_DESCRIPTOR)
package-windows: GOOS:=windows
package-windows: GOOS_DIR:=$(BUILD_DIR)/$(GOOS)
package-windows: ARCHIVE_NAME=lifecycle-v$(LIFECYCLE_VERSION)+$(GOOS).x86-64
package-windows:
	@echo "> Writing descriptor file for $(GOOS)..."
	mkdir -p $(GOOS_DIR)
	echo "$${LIFECYCLE_DESCRIPTOR}" > $(GOOS_DIR)/lifecycle.toml

	@echo "> Packaging lifecycle for $(GOOS)..."
	tar czf $(BUILD_DIR)/$(ARCHIVE_NAME).tgz -C $(GOOS_DIR) lifecycle.toml lifecycle

.PHONY: verify-jq
