# Makefile for deploying the Flutter web projects to GitHub

BASE_HREF = /$(OUTPUT)/
# Replace this with your GitHub username
GITHUB_USER = 962012d09b
GITHUB_REPO = git@github-anon:$(GITHUB_USER)/$(OUTPUT).git
BUILD_VERSION := $(shell python -c "import re; print(re.search(r'version:\s*(\S+)', open('pubspec.yaml').read()).group(1))")

# Anonymous git identity
ANON_GIT_NAME = 962012d09b
ANON_GIT_EMAIL = 962012d09b@users.noreply.github.com

# Deploy the Flutter web project to GitHub
deploy:
ifndef OUTPUT
	$(error OUTPUT is not set. Usage: make deploy OUTPUT=<output_repo_name>)
endif

	@echo "Clean existing repository"
	flutter clean

	@echo "Getting packages..."
	flutter pub get

	@echo "Building for web..."
	flutter build web --base-href $(BASE_HREF) --release

	@echo "Deploying to git repository"
	cd build/web && \
	git init && \
	git config user.name "$(ANON_GIT_NAME)" && \
	git config user.email "$(ANON_GIT_EMAIL)" && \
	git add . && \
	git commit -m "Deploy Version $(BUILD_VERSION)" && \
	git branch -M main && \
	git remote add origin $(GITHUB_REPO) && \
	git push -u -f origin main

	@echo "✅ Finished deploy: $(GITHUB_REPO)"
	@echo "🚀 Flutter web URL: https://$(GITHUB_USER).github.io/$(OUTPUT)/"

.PHONY: deploy