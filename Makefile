# Makefile for OCR Simple Application

# Variables
APP_NAME=ocr-app
MAIN_FILE=main.go
BUILD_DIR=./build
BINARY_NAME=$(APP_NAME)
GO_VERSION=1.23.6
VERSION=$(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_TIME=$(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_COMMIT=$(shell git rev-parse HEAD 2>/dev/null || echo "unknown")

# Environment-specific variables
DEV_PORT=8080
STAGING_PORT=8081
PROD_PORT=80

# Build flags
LDFLAGS=-ldflags "-s -w -X main.Version=$(VERSION) -X main.BuildTime=$(BUILD_TIME) -X main.GitCommit=$(GIT_COMMIT)"
DEV_LDFLAGS=-ldflags "-X main.Version=$(VERSION) -X main.BuildTime=$(BUILD_TIME) -X main.GitCommit=$(GIT_COMMIT)"

# Colors for output
RED=\033[0;31m
GREEN=\033[0;32m
YELLOW=\033[1;33m
BLUE=\033[0;34m
PURPLE=\033[0;35m
CYAN=\033[0;36m
NC=\033[0m # No Color

# Default target
.DEFAULT_GOAL := help

# Help target
.PHONY: help
help: ## Show this help message
	@echo "$(BLUE)OCR Simple Application - Available Commands:$(NC)"
	@echo ""
	@echo "$(PURPLE)🚀 Quick Start:$(NC)"
	@echo "  $(GREEN)make first-run$(NC)     - Complete setup and start development"
	@echo "  $(GREEN)make dev$(NC)           - Start development server"
	@echo "  $(GREEN)make build-prod$(NC)    - Build for production"
	@echo ""
	@echo "$(PURPLE)🌍 Cross-Platform Building:$(NC)"
	@echo "  $(GREEN)make build-windows$(NC)        - Build for Windows (64-bit)"
	@echo "  $(GREEN)make build-macos$(NC)          - Build for macOS (Intel)"
	@echo "  $(GREEN)make build-macos-arm64$(NC)    - Build for macOS (Apple Silicon)"
	@echo "  $(GREEN)make build-linux$(NC)          - Build for Linux (64-bit, CGO disabled on macOS)"
	@echo "  $(GREEN)make build-linux-cgo$(NC)     - Build for Linux with CGO (requires Linux)"
	@echo "  $(GREEN)make docker-build-linux$(NC)  - Build for Linux using Docker (with CGO)"
	@echo "  $(GREEN)make build-cross-platform$(NC) - Build for all platforms"
	@echo "  $(GREEN)make package-all$(NC)          - Create distribution packages"
	@echo "  $(GREEN)make release$(NC)              - Prepare complete release"
	@echo ""
	@echo "$(PURPLE)📋 All Commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-25s$(NC) %s\n", $$1, $$2}'
	@echo ""

# Environment detection
.PHONY: detect-env
detect-env: ## Detect current environment
	@echo "$(BLUE)Environment Detection:$(NC)"
	@if [ -f .env.development ]; then echo "$(GREEN)Development environment detected$(NC)"; fi
	@if [ -f .env.staging ]; then echo "$(YELLOW)Staging environment detected$(NC)"; fi
	@if [ -f .env.production ]; then echo "$(RED)Production environment detected$(NC)"; fi

# Create environment files
.PHONY: create-env-files
create-env-files: ## Create environment configuration files
	@echo "$(BLUE)Creating environment files...$(NC)"
	@echo "# Development Environment" > .env.development
	@echo "APP_ENV=development" >> .env.development
	@echo "PORT=$(DEV_PORT)" >> .env.development
	@echo "DEBUG=true" >> .env.development
	@echo "LOG_LEVEL=debug" >> .env.development
	@echo "OCR_TIMEOUT=30" >> .env.development
	@echo "MAX_FILE_SIZE=5242880" >> .env.development
	@echo "WORKER_COUNT=3" >> .env.development
	@echo >> .env.development
	@echo "# Staging Environment" > .env.staging
	@echo "APP_ENV=staging" >> .env.staging
	@echo "PORT=$(STAGING_PORT)" >> .env.staging
	@echo "DEBUG=false" >> .env.staging
	@echo "LOG_LEVEL=info" >> .env.staging
	@echo "OCR_TIMEOUT=45" >> .env.staging
	@echo "MAX_FILE_SIZE=10485760" >> .env.staging
	@echo "WORKER_COUNT=5" >> .env.staging
	@echo >> .env.staging
	@echo "# Production Environment" > .env.production
	@echo "APP_ENV=production" >> .env.production
	@echo "PORT=$(PROD_PORT)" >> .env.production
	@echo "DEBUG=false" >> .env.production
	@echo "LOG_LEVEL=warn" >> .env.production
	@echo "OCR_TIMEOUT=60" >> .env.production
	@echo "MAX_FILE_SIZE=10485760" >> .env.production
	@echo "WORKER_COUNT=8" >> .env.production
	@echo "ENABLE_METRICS=true" >> .env.production
	@echo >> .env.production
	@echo "$(GREEN)Environment files created:$(NC)"
	@echo "  .env.development"
	@echo "  .env.staging" 
	@echo "  .env.production"

# Check if Go is installed
.PHONY: check-go
check-go: ## Check if Go is installed
	@echo "$(BLUE)Checking Go installation...$(NC)"
	@which go > /dev/null || (echo "$(RED)Error: Go is not installed. Please install Go $(GO_VERSION) or later.$(NC)" && exit 1)
	@echo "$(GREEN)Go is installed: $$(go version)$(NC)"

# Check if Tesseract is installed
.PHONY: check-tesseract
check-tesseract: ## Check if Tesseract OCR is installed
	@echo "$(BLUE)Checking Tesseract installation...$(NC)"
	@which tesseract > /dev/null || (echo "$(RED)Error: Tesseract is not installed. Please install Tesseract OCR.$(NC)" && exit 1)
	@echo "$(GREEN)Tesseract is installed: $$(tesseract --version | head -n1)$(NC)"

# Check all dependencies
.PHONY: check-deps
check-deps: check-go check-tesseract ## Check all required dependencies
	@echo "$(GREEN)All dependencies are satisfied!$(NC)"

# Install Go dependencies
.PHONY: deps
deps: check-go ## Download and install Go dependencies
	@echo "$(BLUE)Installing Go dependencies...$(NC)"
	go mod download
	go mod tidy
	go mod verify
	@echo "$(GREEN)Dependencies installed successfully!$(NC)"

# Build for development
.PHONY: build-dev
build-dev: check-deps ## Build for development environment
	@echo "$(BLUE)Building $(APP_NAME) for development...$(NC)"
	@mkdir -p $(BUILD_DIR)/dev
	CGO_ENABLED=1 go build $(DEV_LDFLAGS) -race -o $(BUILD_DIR)/dev/$(BINARY_NAME) $(MAIN_FILE)
	@echo "$(GREEN)Development build completed: $(BUILD_DIR)/dev/$(BINARY_NAME)$(NC)"

# Build for staging
.PHONY: build-staging
build-staging: check-deps ## Build for staging environment
	@echo "$(BLUE)Building $(APP_NAME) for staging...$(NC)"
	@mkdir -p $(BUILD_DIR)/staging
	CGO_ENABLED=1 go build $(LDFLAGS) -o $(BUILD_DIR)/staging/$(BINARY_NAME) $(MAIN_FILE)
	@echo "$(GREEN)Staging build completed: $(BUILD_DIR)/staging/$(BINARY_NAME)$(NC)"

# Build for production
.PHONY: build-prod
build-prod: check-deps ## Build for production environment
	@echo "$(BLUE)Building $(APP_NAME) for production...$(NC)"
	@mkdir -p $(BUILD_DIR)/prod
	CGO_ENABLED=1 go build $(LDFLAGS) -trimpath -o $(BUILD_DIR)/prod/$(BINARY_NAME) $(MAIN_FILE)
	@echo "$(GREEN)Production build completed: $(BUILD_DIR)/prod/$(BINARY_NAME)$(NC)"

# Build all environments
.PHONY: build-all
build-all: build-dev build-staging build-prod ## Build for all environments
	@echo "$(GREEN)All builds completed!$(NC)"

# Cross-platform build targets
.PHONY: build-windows
build-windows: check-deps ## Build for Windows (amd64)
	@echo "$(BLUE)Building $(APP_NAME) for Windows (amd64)...$(NC)"
	@mkdir -p $(BUILD_DIR)/windows/amd64
	CGO_ENABLED=1 GOOS=windows GOARCH=amd64 CC=x86_64-w64-mingw32-gcc go build $(LDFLAGS) -trimpath -o $(BUILD_DIR)/windows/amd64/$(BINARY_NAME).exe $(MAIN_FILE)
	@echo "$(GREEN)Windows build completed: $(BUILD_DIR)/windows/amd64/$(BINARY_NAME).exe$(NC)"

.PHONY: build-windows-386
build-windows-386: check-deps ## Build for Windows (386)
	@echo "$(BLUE)Building $(APP_NAME) for Windows (386)...$(NC)"
	@mkdir -p $(BUILD_DIR)/windows/386
	CGO_ENABLED=1 GOOS=windows GOARCH=386 CC=i686-w64-mingw32-gcc go build $(LDFLAGS) -trimpath -o $(BUILD_DIR)/windows/386/$(BINARY_NAME).exe $(MAIN_FILE)
	@echo "$(GREEN)Windows 32-bit build completed: $(BUILD_DIR)/windows/386/$(BINARY_NAME).exe$(NC)"

.PHONY: build-macos
build-macos: check-deps ## Build for macOS (amd64)
	@echo "$(BLUE)Building $(APP_NAME) for macOS (amd64)...$(NC)"
	@mkdir -p $(BUILD_DIR)/darwin/amd64
	CGO_ENABLED=1 GOOS=darwin GOARCH=amd64 go build $(LDFLAGS) -trimpath -o $(BUILD_DIR)/darwin/amd64/$(BINARY_NAME) $(MAIN_FILE)
	@echo "$(GREEN)macOS Intel build completed: $(BUILD_DIR)/darwin/amd64/$(BINARY_NAME)$(NC)"

.PHONY: build-macos-arm64
build-macos-arm64: check-deps ## Build for macOS Apple Silicon (arm64)
	@echo "$(BLUE)Building $(APP_NAME) for macOS Apple Silicon (arm64)...$(NC)"
	@mkdir -p $(BUILD_DIR)/darwin/arm64
	CGO_ENABLED=1 GOOS=darwin GOARCH=arm64 go build $(LDFLAGS) -trimpath -o $(BUILD_DIR)/darwin/arm64/$(BINARY_NAME) $(MAIN_FILE)
	@echo "$(GREEN)macOS Apple Silicon build completed: $(BUILD_DIR)/darwin/arm64/$(BINARY_NAME)$(NC)"

.PHONY: build-linux
build-linux: check-deps ## Build for Linux (amd64)
	@echo "$(BLUE)Building $(APP_NAME) for Linux (amd64)...$(NC)"
	@mkdir -p $(BUILD_DIR)/linux/amd64
	@if [[ "$$(uname)" == "Darwin" ]]; then \
		echo "$(YELLOW)Cross-compiling from macOS to Linux (CGO disabled)...$(NC)"; \
		CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -trimpath -o $(BUILD_DIR)/linux/amd64/$(BINARY_NAME) $(MAIN_FILE); \
	else \
		CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -trimpath -o $(BUILD_DIR)/linux/amd64/$(BINARY_NAME) $(MAIN_FILE); \
	fi
	@echo "$(GREEN)Linux build completed: $(BUILD_DIR)/linux/amd64/$(BINARY_NAME)$(NC)"

.PHONY: build-linux-386
build-linux-386: check-deps ## Build for Linux (386)
	@echo "$(BLUE)Building $(APP_NAME) for Linux (386)...$(NC)"
	@mkdir -p $(BUILD_DIR)/linux/386
	@if [[ "$$(uname)" == "Darwin" ]]; then \
		echo "$(YELLOW)Cross-compiling from macOS to Linux (CGO disabled)...$(NC)"; \
		CGO_ENABLED=0 GOOS=linux GOARCH=386 go build $(LDFLAGS) -trimpath -o $(BUILD_DIR)/linux/386/$(BINARY_NAME) $(MAIN_FILE); \
	else \
		CGO_ENABLED=1 GOOS=linux GOARCH=386 go build $(LDFLAGS) -trimpath -o $(BUILD_DIR)/linux/386/$(BINARY_NAME) $(MAIN_FILE); \
	fi
	@echo "$(GREEN)Linux 32-bit build completed: $(BUILD_DIR)/linux/386/$(BINARY_NAME)$(NC)"

.PHONY: build-linux-arm64
build-linux-arm64: check-deps ## Build for Linux ARM64
	@echo "$(BLUE)Building $(APP_NAME) for Linux (arm64)...$(NC)"
	@mkdir -p $(BUILD_DIR)/linux/arm64
	@if [[ "$$(uname)" == "Darwin" ]]; then \
		echo "$(YELLOW)Cross-compiling from macOS to Linux (CGO disabled)...$(NC)"; \
		CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build $(LDFLAGS) -trimpath -o $(BUILD_DIR)/linux/arm64/$(BINARY_NAME) $(MAIN_FILE); \
	else \
		CGO_ENABLED=1 GOOS=linux GOARCH=arm64 go build $(LDFLAGS) -trimpath -o $(BUILD_DIR)/linux/arm64/$(BINARY_NAME) $(MAIN_FILE); \
	fi
	@echo "$(GREEN)Linux ARM64 build completed: $(BUILD_DIR)/linux/arm64/$(BINARY_NAME)$(NC)"

.PHONY: build-linux-arm
build-linux-arm: check-deps ## Build for Linux ARM
	@echo "$(BLUE)Building $(APP_NAME) for Linux (arm)...$(NC)"
	@mkdir -p $(BUILD_DIR)/linux/arm
	@if [[ "$$(uname)" == "Darwin" ]]; then \
		echo "$(YELLOW)Cross-compiling from macOS to Linux (CGO disabled)...$(NC)"; \
		CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 go build $(LDFLAGS) -trimpath -o $(BUILD_DIR)/linux/arm/$(BINARY_NAME) $(MAIN_FILE); \
	else \
		CGO_ENABLED=1 GOOS=linux GOARCH=arm GOARM=7 go build $(LDFLAGS) -trimpath -o $(BUILD_DIR)/linux/arm/$(BINARY_NAME) $(MAIN_FILE); \
	fi
	@echo "$(GREEN)Linux ARM build completed: $(BUILD_DIR)/linux/arm/$(BINARY_NAME)$(NC)"

# Build Linux with CGO (requires Linux environment or Docker)
.PHONY: build-linux-cgo
build-linux-cgo: check-deps ## Build for Linux with CGO enabled (requires Linux environment)
	@echo "$(BLUE)Building $(APP_NAME) for Linux with CGO enabled...$(NC)"
	@if [[ "$$(uname)" != "Linux" ]]; then \
		echo "$(RED)Warning: Building Linux binaries with CGO from non-Linux systems may fail.$(NC)"; \
		echo "$(YELLOW)Consider using Docker or a Linux environment for CGO builds.$(NC)"; \
	fi
	@mkdir -p $(BUILD_DIR)/linux/amd64
	CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -trimpath -o $(BUILD_DIR)/linux/amd64/$(BINARY_NAME)-cgo $(MAIN_FILE)
	@echo "$(GREEN)Linux CGO build completed: $(BUILD_DIR)/linux/amd64/$(BINARY_NAME)-cgo$(NC)"

# Build for all platforms
.PHONY: build-cross-platform
build-cross-platform: build-windows build-windows-386 build-macos build-macos-arm64 build-linux build-linux-386 build-linux-arm64 build-linux-arm ## Build for all platforms
	@echo "$(GREEN)Cross-platform builds completed!$(NC)"
	@if [[ "$$(uname)" == "Darwin" ]]; then \
		echo "$(YELLOW)Note: Linux builds were compiled with CGO disabled for cross-platform compatibility.$(NC)"; \
		echo "$(YELLOW)For CGO-enabled Linux builds, use 'make build-linux-cgo' on a Linux system.$(NC)"; \
	fi
	@echo "$(BLUE)Available builds:$(NC)"
	@find $(BUILD_DIR) -name "$(BINARY_NAME)*" -type f -exec echo "  {}" \;

# Build for specific platforms
.PHONY: build-all-windows
build-all-windows: build-windows build-windows-386 ## Build for all Windows architectures
	@echo "$(GREEN)All Windows builds completed!$(NC)"

.PHONY: build-all-macos
build-all-macos: build-macos build-macos-arm64 ## Build for all macOS architectures
	@echo "$(GREEN)All macOS builds completed!$(NC)"

.PHONY: build-all-linux
build-all-linux: build-linux build-linux-386 build-linux-arm64 build-linux-arm ## Build for all Linux architectures
	@echo "$(GREEN)All Linux builds completed!$(NC)"

# Create distribution packages
.PHONY: package-windows
package-windows: build-all-windows ## Create Windows distribution packages
	@echo "$(BLUE)Creating Windows distribution packages...$(NC)"
	@mkdir -p $(BUILD_DIR)/dist/windows
	@cd $(BUILD_DIR)/windows/amd64 && zip -r ../../dist/windows/$(APP_NAME)-$(VERSION)-windows-amd64.zip $(BINARY_NAME).exe
	@cd $(BUILD_DIR)/windows/386 && zip -r ../../dist/windows/$(APP_NAME)-$(VERSION)-windows-386.zip $(BINARY_NAME).exe
	@echo "$(GREEN)Windows packages created in $(BUILD_DIR)/dist/windows/$(NC)"

.PHONY: package-macos
package-macos: build-all-macos ## Create macOS distribution packages
	@echo "$(BLUE)Creating macOS distribution packages...$(NC)"
	@mkdir -p $(BUILD_DIR)/dist/macos
	@cd $(BUILD_DIR)/darwin/amd64 && tar -czf ../../dist/macos/$(APP_NAME)-$(VERSION)-darwin-amd64.tar.gz $(BINARY_NAME)
	@cd $(BUILD_DIR)/darwin/arm64 && tar -czf ../../dist/macos/$(APP_NAME)-$(VERSION)-darwin-arm64.tar.gz $(BINARY_NAME)
	@echo "$(GREEN)macOS packages created in $(BUILD_DIR)/dist/macos/$(NC)"

.PHONY: package-linux
package-linux: build-all-linux ## Create Linux distribution packages
	@echo "$(BLUE)Creating Linux distribution packages...$(NC)"
	@mkdir -p $(BUILD_DIR)/dist/linux
	@cd $(BUILD_DIR)/linux/amd64 && tar -czf ../../dist/linux/$(APP_NAME)-$(VERSION)-linux-amd64.tar.gz $(BINARY_NAME)
	@cd $(BUILD_DIR)/linux/386 && tar -czf ../../dist/linux/$(APP_NAME)-$(VERSION)-linux-386.tar.gz $(BINARY_NAME)
	@cd $(BUILD_DIR)/linux/arm64 && tar -czf ../../dist/linux/$(APP_NAME)-$(VERSION)-linux-arm64.tar.gz $(BINARY_NAME)
	@cd $(BUILD_DIR)/linux/arm && tar -czf ../../dist/linux/$(APP_NAME)-$(VERSION)-linux-arm.tar.gz $(BINARY_NAME)
	@echo "$(GREEN)Linux packages created in $(BUILD_DIR)/dist/linux/$(NC)"

.PHONY: package-all
package-all: package-windows package-macos package-linux ## Create all distribution packages
	@echo "$(GREEN)All distribution packages created!$(NC)"
	@echo "$(BLUE)Available packages:$(NC)"
	@find $(BUILD_DIR)/dist -name "*.zip" -o -name "*.tar.gz" | sort

# Release preparation
.PHONY: release
release: clean build-cross-platform package-all ## Prepare complete release
	@echo "$(GREEN)Release preparation completed!$(NC)"
	@echo "$(BLUE)Release $(VERSION) contents:$(NC)"
	@find $(BUILD_DIR)/dist -name "*$(VERSION)*" | sort

# Install cross-compilation tools
.PHONY: install-cross-tools
install-cross-tools: ## Install cross-compilation tools
	@echo "$(BLUE)Installing cross-compilation tools...$(NC)"
	@if [[ "$$(uname)" == "Darwin" ]]; then \
		echo "$(YELLOW)Installing macOS cross-compilation tools...$(NC)"; \
		if which brew > /dev/null; then \
			brew install mingw-w64; \
		else \
			echo "$(RED)Homebrew not found. Install from: https://brew.sh$(NC)"; \
		fi; \
	elif [[ "$$(uname)" == "Linux" ]]; then \
		echo "$(YELLOW)Installing Linux cross-compilation tools...$(NC)"; \
		if which apt-get > /dev/null; then \
			sudo apt-get update && sudo apt-get install -y gcc-mingw-w64; \
		elif which dnf > /dev/null; then \
			sudo dnf install -y mingw64-gcc mingw32-gcc; \
		elif which yum > /dev/null; then \
			sudo yum install -y mingw64-gcc mingw32-gcc; \
		else \
			echo "$(RED)Package manager not supported. Install mingw-w64 manually.$(NC)"; \
		fi; \
	else \
		echo "$(YELLOW)Cross-compilation tools installation not automated for this platform.$(NC)"; \
	fi
	@echo "$(GREEN)Cross-compilation tools installation completed!$(NC)"

# Troubleshooting and diagnostics
.PHONY: diagnose
diagnose: ## Diagnose build environment and common issues
	@echo "$(BLUE)Diagnosing build environment...$(NC)"
	@echo "$(PURPLE)System Information:$(NC)"
	@echo "  OS: $$(uname -s)"
	@echo "  Architecture: $$(uname -m)"
	@echo "  Go Version: $$(go version 2>/dev/null || echo 'Go not found')"
	@echo "  Tesseract: $$(tesseract --version 2>/dev/null | head -n1 || echo 'Tesseract not found')"
	@echo "  Docker: $$(docker --version 2>/dev/null || echo 'Docker not found')"
	@echo "$(PURPLE)Cross-compilation Support:$(NC)"
	@if [[ "$$(uname)" == "Darwin" ]]; then \
		echo "  $(YELLOW)macOS detected - Linux builds will use CGO_ENABLED=0$(NC)"; \
		echo "  $(YELLOW)For CGO-enabled Linux builds, use Docker or Linux environment$(NC)"; \
		if which x86_64-w64-mingw32-gcc > /dev/null; then \
			echo "  $(GREEN)Windows cross-compiler: Available$(NC)"; \
		else \
			echo "  $(RED)Windows cross-compiler: Missing (run 'make install-cross-tools')$(NC)"; \
		fi; \
	else \
		echo "  $(GREEN)Native Linux environment - CGO builds supported$(NC)"; \
	fi
	@echo "$(PURPLE)Build Recommendations:$(NC)"
	@if [[ "$$(uname)" == "Darwin" ]]; then \
		echo "  - Use 'make build-cross-platform' for basic cross-platform builds"; \
		echo "  - Use 'make docker-build-linux' for Linux builds with CGO support"; \
		echo "  - Use 'make build-linux-cgo' only on Linux systems"; \
	else \
		echo "  - All build targets should work natively"; \
		echo "  - CGO is fully supported for all architectures"; \
	fi

# Legacy build (for backward compatibility)
.PHONY: build
build: build-dev ## Build the application (defaults to development)

# Run in development
.PHONY: run-dev
run-dev: check-deps ## Run in development mode
	@echo "$(BLUE)Starting $(APP_NAME) in development mode...$(NC)"
	@echo "$(YELLOW)Loading development environment...$(NC)"
	@if [ -f .env.development ]; then \
		export $$(cat .env.development | xargs) && go run $(MAIN_FILE); \
	else \
		APP_ENV=development PORT=$(DEV_PORT) DEBUG=true go run $(MAIN_FILE); \
	fi

# Run in staging
.PHONY: run-staging
run-staging: build-staging ## Run in staging mode
	@echo "$(BLUE)Starting $(APP_NAME) in staging mode...$(NC)"
	@echo "$(YELLOW)Loading staging environment...$(NC)"
	@if [ -f .env.staging ]; then \
		export $$(cat .env.staging | xargs) && $(BUILD_DIR)/staging/$(BINARY_NAME); \
	else \
		APP_ENV=staging PORT=$(STAGING_PORT) $(BUILD_DIR)/staging/$(BINARY_NAME); \
	fi

# Run in production
.PHONY: run-prod
run-prod: build-prod ## Run in production mode
	@echo "$(BLUE)Starting $(APP_NAME) in production mode...$(NC)"
	@echo "$(YELLOW)Loading production environment...$(NC)"
	@if [ -f .env.production ]; then \
		export $$(cat .env.production | xargs) && $(BUILD_DIR)/prod/$(BINARY_NAME); \
	else \
		APP_ENV=production PORT=$(PROD_PORT) $(BUILD_DIR)/prod/$(BINARY_NAME); \
	fi

# Legacy run commands
.PHONY: run
run: run-dev ## Run the application (defaults to development)

.PHONY: start
start: run-dev ## Start the application (defaults to development)

# Development mode with auto-reload
.PHONY: dev
dev: check-deps ## Run in development mode with auto-reload
	@echo "$(BLUE)Starting development server with auto-reload...$(NC)"
	@if which air > /dev/null; then \
		echo "$(GREEN)Using air for auto-reload$(NC)"; \
		if [ -f .env.development ]; then \
			export $$(cat .env.development | xargs); \
		else \
			export APP_ENV=development PORT=$(DEV_PORT) DEBUG=true; \
		fi; \
		air; \
	else \
		echo "$(YELLOW)Air not found. Install with: make install-dev-tools$(NC)"; \
		echo "$(BLUE)Running without auto-reload...$(NC)"; \
		make run-dev; \
	fi

# Docker builds
.PHONY: docker-build-dev
docker-build-dev: ## Build Docker image for development
	@echo "$(BLUE)Building Docker image for development...$(NC)"
	docker build -f Dockerfile.dev -t $(APP_NAME):dev-$(VERSION) .
	@echo "$(GREEN)Development Docker image built: $(APP_NAME):dev-$(VERSION)$(NC)"

.PHONY: docker-build-prod
docker-build-prod: ## Build Docker image for production
	@echo "$(BLUE)Building Docker image for production...$(NC)"
	docker build -f Dockerfile -t $(APP_NAME):$(VERSION) -t $(APP_NAME):latest .
	@echo "$(GREEN)Production Docker image built: $(APP_NAME):$(VERSION)$(NC)"

.PHONY: docker-build-linux
docker-build-linux: ## Build Linux binaries using Docker (with CGO support)
	@echo "$(BLUE)Building Linux binaries using Docker...$(NC)"
	@if ! which docker > /dev/null; then \
		echo "$(RED)Error: Docker is not installed or not in PATH$(NC)"; \
		exit 1; \
	fi
	@mkdir -p $(BUILD_DIR)/linux/amd64
	docker run --rm -v "$$(pwd)":/workspace -w /workspace golang:1.23-alpine sh -c \
		"apk add --no-cache gcc musl-dev tesseract-ocr-dev && \
		CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -trimpath -o $(BUILD_DIR)/linux/amd64/$(BINARY_NAME)-docker $(MAIN_FILE)"
	@echo "$(GREEN)Docker Linux build completed: $(BUILD_DIR)/linux/amd64/$(BINARY_NAME)-docker$(NC)"

# Install development tools
.PHONY: install-dev-tools
install-dev-tools: ## Install development tools
	@echo "$(BLUE)Installing development tools...$(NC)"
	go install github.com/cosmtrek/air@latest
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	@echo "$(GREEN)Development tools installed!$(NC)"

# Test with different configurations
.PHONY: test
test: check-deps ## Run tests
	@echo "$(BLUE)Running tests...$(NC)"
	go test -v -race ./...
	@echo "$(GREEN)Tests completed!$(NC)"

.PHONY: test-coverage
test-coverage: check-deps ## Run tests with coverage
	@echo "$(BLUE)Running tests with coverage...$(NC)"
	go test -v -race -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "$(GREEN)Coverage report: coverage.html$(NC)"

.PHONY: benchmark
benchmark: check-deps ## Run benchmarks
	@echo "$(BLUE)Running benchmarks...$(NC)"
	go test -bench=. -benchmem ./...
	@echo "$(GREEN)Benchmarks completed!$(NC)"

# Code quality
.PHONY: fmt
fmt: ## Format Go code
	@echo "$(BLUE)Formatting code...$(NC)"
	go fmt ./...
	@echo "$(GREEN)Code formatted!$(NC)"

.PHONY: lint
lint: ## Lint Go code
	@echo "$(BLUE)Linting code...$(NC)"
	@if which golangci-lint > /dev/null; then \
		golangci-lint run; \
		echo "$(GREEN)Linting completed!$(NC)"; \
	else \
		echo "$(YELLOW)golangci-lint not found. Run: make install-dev-tools$(NC)"; \
	fi

.PHONY: vet
vet: ## Vet Go code
	@echo "$(BLUE)Vetting code...$(NC)"
	go vet ./...
	@echo "$(GREEN)Vetting completed!$(NC)"

.PHONY: security
security: ## Run security checks
	@echo "$(BLUE)Running security checks...$(NC)"
	@if which gosec > /dev/null; then \
		gosec ./...; \
		echo "$(GREEN)Security checks completed!$(NC)"; \
	else \
		echo "$(YELLOW)gosec not found. Install with: go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest$(NC)"; \
	fi

# Clean operations
.PHONY: clean
clean: ## Clean build artifacts
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	rm -rf $(BUILD_DIR)
	rm -f coverage.out coverage.html
	rm -rf tmp/
	@echo "$(GREEN)Clean completed!$(NC)"

.PHONY: clean-all
clean-all: clean ## Clean everything including dependencies
	@echo "$(BLUE)Cleaning all artifacts and dependencies...$(NC)"
	go clean -modcache
	go clean -cache
	docker system prune -f 2>/dev/null || true
	@echo "$(GREEN)Deep clean completed!$(NC)"

# Platform-specific Tesseract installation
.PHONY: install-tesseract-mac
install-tesseract-mac: ## Install Tesseract on macOS
	@echo "$(BLUE)Installing Tesseract OCR on macOS...$(NC)"
	@if which brew > /dev/null; then \
		brew install tesseract tesseract-lang; \
		echo "$(GREEN)Tesseract installed successfully!$(NC)"; \
	else \
		echo "$(RED)Homebrew not found. Install from: https://brew.sh$(NC)"; \
	fi

.PHONY: install-tesseract-ubuntu
install-tesseract-ubuntu: ## Install Tesseract on Ubuntu/Debian
	@echo "$(BLUE)Installing Tesseract OCR on Ubuntu/Debian...$(NC)"
	sudo apt-get update
	sudo apt-get install -y tesseract-ocr tesseract-ocr-eng tesseract-ocr-ind
	@echo "$(GREEN)Tesseract installed successfully!$(NC)"

.PHONY: install-tesseract-centos
install-tesseract-centos: ## Install Tesseract on CentOS/RHEL/Fedora
	@echo "$(BLUE)Installing Tesseract OCR on CentOS/RHEL/Fedora...$(NC)"
	sudo dnf install -y tesseract tesseract-langpack-eng tesseract-langpack-ind
	@echo "$(GREEN)Tesseract installed successfully!$(NC)"

# Create air configuration
.PHONY: create-air-config
create-air-config: ## Create air configuration for development
	@echo "$(BLUE)Creating air configuration...$(NC)"
	@echo 'root = "."' > .air.toml
	@echo 'testdata_dir = "testdata"' >> .air.toml
	@echo 'tmp_dir = "tmp"' >> .air.toml
	@echo '' >> .air.toml
	@echo '[build]' >> .air.toml
	@echo '  args_bin = []' >> .air.toml
	@echo '  bin = "./tmp/main"' >> .air.toml
	@echo '  cmd = "go build -o ./tmp/main ."' >> .air.toml
	@echo '  delay = 1000' >> .air.toml
	@echo '  exclude_dir = ["assets", "tmp", "vendor", "testdata", "build"]' >> .air.toml
	@echo '  exclude_file = []' >> .air.toml
	@echo '  exclude_regex = ["_test.go"]' >> .air.toml
	@echo '  exclude_unchanged = false' >> .air.toml
	@echo '  follow_symlink = false' >> .air.toml
	@echo '  full_bin = ""' >> .air.toml
	@echo '  include_dir = []' >> .air.toml
	@echo '  include_ext = ["go", "tpl", "tmpl", "html"]' >> .air.toml
	@echo '  kill_delay = "0s"' >> .air.toml
	@echo '  log = "build-errors.log"' >> .air.toml
	@echo '  send_interrupt = false' >> .air.toml
	@echo '  stop_on_root = false' >> .air.toml
	@echo '' >> .air.toml
	@echo '[color]' >> .air.toml
	@echo '  app = ""' >> .air.toml
	@echo '  build = "yellow"' >> .air.toml
	@echo '  main = "magenta"' >> .air.toml
	@echo '  runner = "green"' >> .air.toml
	@echo '  watcher = "cyan"' >> .air.toml
	@echo '' >> .air.toml
	@echo '[log]' >> .air.toml
	@echo '  time = false' >> .air.toml
	@echo '' >> .air.toml
	@echo '[misc]' >> .air.toml
	@echo '  clean_on_exit = false' >> .air.toml
	@echo '' >> .air.toml
	@echo '[screen]' >> .air.toml
	@echo '  clear_on_rebuild = true' >> .air.toml
	@echo "$(GREEN)Air configuration created: .air.toml$(NC)"

# Environment setup
.PHONY: setup-dev
setup-dev: check-deps deps install-dev-tools create-env-files create-air-config ## Setup development environment
	@echo "$(GREEN)Development environment setup completed!$(NC)"

.PHONY: setup-staging
setup-staging: check-deps deps create-env-files ## Setup staging environment
	@echo "$(GREEN)Staging environment setup completed!$(NC)"

.PHONY: setup-prod
setup-prod: check-deps deps create-env-files ## Setup production environment
	@echo "$(GREEN)Production environment setup completed!$(NC)"

# Legacy setup
.PHONY: setup
setup: setup-dev ## Setup development environment (default)

# Deployment helpers
.PHONY: deploy-staging
deploy-staging: build-staging ## Deploy to staging
	@echo "$(BLUE)Deploying to staging...$(NC)"
	@echo "$(YELLOW)Copy $(BUILD_DIR)/staging/$(BINARY_NAME) to your staging server$(NC)"
	@echo "$(YELLOW)Don't forget to copy .env.staging as well$(NC)"

.PHONY: deploy-prod
deploy-prod: build-prod ## Deploy to production
	@echo "$(BLUE)Deploying to production...$(NC)"
	@echo "$(YELLOW)Copy $(BUILD_DIR)/prod/$(BINARY_NAME) to your production server$(NC)"
	@echo "$(YELLOW)Don't forget to copy .env.production as well$(NC)"

# Utility commands
.PHONY: info
info: ## Show application and environment information
	@echo "$(BLUE)Application Information:$(NC)"
	@echo "Name: $(APP_NAME)"
	@echo "Version: $(VERSION)"
	@echo "Build Time: $(BUILD_TIME)"
	@echo "Git Commit: $(GIT_COMMIT)"
	@echo "Main file: $(MAIN_FILE)"
	@echo "Build directory: $(BUILD_DIR)"
	@echo ""
	@echo "$(BLUE)Environment Ports:$(NC)"
	@echo "Development: $(DEV_PORT)"
	@echo "Staging: $(STAGING_PORT)"
	@echo "Production: $(PROD_PORT)"
	@echo ""
	@echo "$(BLUE)Cross-Platform Targets:$(NC)"
	@echo "Windows: windows/amd64, windows/386"
	@echo "macOS: darwin/amd64, darwin/arm64"
	@echo "Linux: linux/amd64, linux/386, linux/arm64, linux/arm"
	@echo ""
	@echo "$(BLUE)Dependencies:$(NC)"
	@go list -m all 2>/dev/null || echo "Run 'make deps' first"

.PHONY: list-builds
list-builds: ## List all available builds
	@echo "$(BLUE)Available builds:$(NC)"
	@if [ -d "$(BUILD_DIR)" ]; then \
		find $(BUILD_DIR) -name "$(BINARY_NAME)*" -type f -exec echo "  {}" \; | sort; \
	else \
		echo "$(YELLOW)No builds found. Run 'make build-cross-platform' first.$(NC)"; \
	fi

.PHONY: list-packages
list-packages: ## List all distribution packages
	@echo "$(BLUE)Available packages:$(NC)"
	@if [ -d "$(BUILD_DIR)/dist" ]; then \
		find $(BUILD_DIR)/dist -name "*.zip" -o -name "*.tar.gz" | sort; \
	else \
		echo "$(YELLOW)No packages found. Run 'make package-all' first.$(NC)"; \
	fi

.PHONY: check-port
check-port: ## Check if ports are available
	@echo "$(BLUE)Checking port availability...$(NC)"
	@for port in $(DEV_PORT) $(STAGING_PORT) $(PROD_PORT); do \
		if lsof -Pi :$$port -sTCP:LISTEN -t >/dev/null 2>&1; then \
			echo "$(RED)Port $$port is in use$(NC)"; \
		else \
			echo "$(GREEN)Port $$port is available$(NC)"; \
		fi; \
	done

.PHONY: kill-ports
kill-ports: ## Kill processes on all application ports
	@echo "$(BLUE)Killing processes on application ports...$(NC)"
	@for port in $(DEV_PORT) $(STAGING_PORT) $(PROD_PORT); do \
		if lsof -Pi :$$port -sTCP:LISTEN -t >/dev/null 2>&1; then \
			echo "Killing process on port $$port"; \
			lsof -ti:$$port | xargs kill -9 2>/dev/null || true; \
		fi; \
	done
	@echo "$(GREEN)All processes killed!$(NC)"

# All-in-one commands
.PHONY: first-run
first-run: setup-dev ## Complete first-time setup and run development
	@echo "$(GREEN)First-time setup completed!$(NC)"
	@echo "$(YELLOW)Starting development server...$(NC)"
	make dev

.PHONY: quick-dev
quick-dev: deps dev ## Quick development start (skip full setup)

.PHONY: quick-prod
quick-prod: deps build-prod run-prod ## Quick production build and run