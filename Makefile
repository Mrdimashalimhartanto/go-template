SHELL=/bin/bash -e -o pipefail
PWD = $(shell pwd)

# constants
GOLANGCI_VERSION = 1.48.0

all: git-hooks generate ## Initializes all tools and files

out:
	@mkdir -pv "$(@)"

test-build: ## Tests whether the code compiles
	@go build -o /dev/null ./...

build: out/bin ## Builds all binaries

GO_BUILD = mkdir -pv "$(@)" && go build -ldflags="-w -s" -o "$(@)" ./...
.PHONY: out/bin
out/bin:
	$(GO_BUILD)

git-hooks:
	@git config --local core.hooksPath .githooks/

download: ## Downloads the dependencies
	@go mod download

fmt: ## Formats all code with go fmt
	@go fmt ./...

run: fmt ## Run a controller from your host
	@go run ./main.go

generate: ## Generates files
	@go run cmd/dotembed/main.go -target _template -o embed_gen.go -pkg gotemplate -var FS
	@go run cmd/options2md/main.go -o docs/options.md

GOLANGCI_LINT = bin/golangci-lint-$(GOLANGCI_VERSION)
$(GOLANGCI_LINT):
	curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | bash -s -- -b bin v$(GOLANGCI_VERSION)
	@mv bin/golangci-lint "$(@)"

lint: fmt $(GOLANGCI_LINT) download ## Lints all code with golangci-lint
	@$(GOLANGCI_LINT) run

lint-reports: out/lint.xml

.PHONY: out/lint.xml
out/lint.xml: $(GOLANGCI_LINT) out download
	$(GOLANGCI_LINT) run ./... --out-format checkstyle | tee "$(@)"

test: ## Runs all tests
	@go test ./...

coverage: out/report.json ## Displays coverage per func on cli
	go tool cover -func=out/cover.out

html-coverage: out/report.json ## Displays the coverage results in the browser
	go tool cover -html=out/cover.out

test-reports: out/report.json

.PHONY: out/report.json
out/report.json: out
	go test ./... -coverprofile=out/cover.out --json | tee "$(@)"

clean-test-project: ## Removes test-project
	@rm -rf testing-project

clean: clean-test-project ## Cleans up everything
	@rm -rf bin out

ci: lint-reports test-reports

.PHONY: testing-project
testing-project: clean-test-project ## Creates a testing-project from the template
	@go run cmd/gt/*.go new -c $$VALUES_FILE

.PHONY: testing-project-ci-single
testing-project-ci-single:  ## Creates a testing-project from the template and run make ci within it
	@make testing-project VALUES_FILE=$$VALUES_FILE
	@make -C testing-project ci
	@make -C testing-project all

.PHONY: testing-project-default
testing-project-default: ## Creates the default testing-project from the template
	@make testing-project VALUES_FILE=pkg/gotemplate/testdata/values.yml

.PHONY: testing-project-ci
testing-project-ci:  ## Creates for all yml files in ./test_project_values a test project and run `make ci`
	for VALUES in ./test_project_values/*.yml; do \
		make testing-project-ci-single VALUES_FILE=$$VALUES; \
	done


help:
	@echo 'Usage: make <OPTIONS> ... <TARGETS>'
	@echo ''
	@echo 'Available targets are:'
	@echo ''
	@grep -E '^[ a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
	@echo ''
