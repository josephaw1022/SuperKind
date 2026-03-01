# SuperKind Makefile

BINARY_NAME=superkind
BIN_DIR=bin
INSTALL_DIR=$(HOME)/.local/bin
INSTALL_PATH=$(INSTALL_DIR)/$(BINARY_NAME)

KIND_DIR=$(HOME)/.kind
KIND_PLUGIN_DIR=$(KIND_DIR)/plugin
BASHRC_D=$(HOME)/.bashrc.d

.PHONY: all
all: build test

.PHONY: build
build:
	@echo "🏗️  Building $(BINARY_NAME)..."
	@mkdir -p $(BIN_DIR)
	go build -o $(BIN_DIR)/$(BINARY_NAME) ./cmd/superkind

.PHONY: test
test:
	@echo "🧪 Running tests..."
	go test ./...

.PHONY: install
install: build
	@echo "📁 Ensuring destination directories exist..."
	@mkdir -p $(INSTALL_DIR)
	@mkdir -p $(KIND_PLUGIN_DIR)
	@mkdir -p $(BASHRC_D)

	@echo "⚙️  Installing $(BINARY_NAME) to $(INSTALL_PATH)..."
	cp $(BIN_DIR)/$(BINARY_NAME) $(INSTALL_PATH)
	chmod +x $(INSTALL_PATH)

	@echo "⚙️  Copying assets..."
	cp -f src/fallback.yaml $(KIND_DIR)/
	cp -f src/index.html $(KIND_DIR)/index.html
	if [ -d src/otel-plugin-extras ]; then \
		cp -r src/otel-plugin-extras $(KIND_DIR)/otel-plugin-extras; \
	fi

	@echo "🔗 Setting up aliases in $(BASHRC_D)/superkind.sh..."
	@echo "alias qk='superkind'" > $(BASHRC_D)/superkind.sh
	@echo "alias quick-kind='superkind'" >> $(BASHRC_D)/superkind.sh
	@echo "alias kind-plugin='superkind plugin'" >> $(BASHRC_D)/superkind.sh
	@echo "export PATH=\"\$$PATH:$(INSTALL_DIR)\"" >> $(BASHRC_D)/superkind.sh

	@echo "✅ SuperKind installed successfully."
	@echo "💡 Make sure your ~/.bashrc sources files in $(BASHRC_D):"
	@echo "   for f in ~/.bashrc.d/*.sh; do source \"\$$f\"; done"

.PHONY: uninstall
uninstall:
	@echo "🧹 Removing SuperKind files..."
	rm -f $(INSTALL_PATH)
	rm -f $(BASHRC_D)/superkind.sh
	rm -rf $(KIND_PLUGIN_DIR)
	@echo "✅ SuperKind uninstalled."

.PHONY: clean
clean:
	@echo "🧹 Cleaning up..."
	rm -rf $(BIN_DIR)

.PHONY: tidy
tidy:
	@echo "🧹 Tidying Go modules..."
	go mod tidy

.PHONY: dev
dev: tidy build test
