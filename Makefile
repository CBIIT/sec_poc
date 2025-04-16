.PHONY: all clone_sec_poc clone_sec_admin clone_sec_nlp update_repos docker_build docker_build_dev docker_build_prod docker_compose docker_compose_dev docker_compose_prod

SEC_POC_DIR = sec_poc
SEC_ADMIN_DIR = sec_admin
SEC_NLP_DIR = sec_nlp
SEC_POC_REPO = https://github.com/CBIIT/sec_poc.git
SEC_ADMIN_REPO = https://github.com/CBIIT/sec_admin.git
SEC_NLP_REPO = https://github.com/CBIIT/sec_nlp.git

all: check_clone update_repos

check_clone: clone_sec_poc clone_sec_admin clone_sec_nlp

clone_sec_poc:
	@if [ ! -d "$(SEC_POC_DIR)" ]; then \
		echo "Cloning sec_poc..."; \
		git clone "$(SEC_POC_REPO)" "$(SEC_POC_DIR)"; \
	else \
		echo "$(SEC_POC_DIR) already exists, skipping clone."; \
	fi

clone_sec_admin:
	@if [ ! -d "$(SEC_ADMIN_DIR)" ]; then \
		echo "Cloning sec_admin..."; \
		git clone "$(SEC_ADMIN_REPO)" "$(SEC_ADMIN_DIR)"; \
	else \
		echo "$(SEC_ADMIN_DIR) already exists, skipping clone."; \
	fi

clone_sec_nlp:
	@if [ ! -d "$(SEC_NLP_DIR)" ]; then \
		echo "Cloning sec_nlp..."; \
		git clone "$(SEC_NLP_REPO)" "$(SEC_NLP_DIR)"; \
	else \
		echo "$(SEC_NLP_DIR) already exists, skipping clone."; \
	fi

update_repos:
	@if [ -d "$(SEC_POC_DIR)" ] || [ -d "$(SEC_ADMIN_DIR)" ] || [ -d "$(SEC_NLP_DIR)" ]; then \
		echo "Updating sec repos..."; \
		[ -d "$(SEC_POC_DIR)" ] && (cd "$(SEC_POC_DIR)" && git fetch && git reset --hard origin/HEAD); \
		[ -d "$(SEC_ADMIN_DIR)" ] && (cd "$(SEC_ADMIN_DIR)" && git fetch && git reset --hard origin/HEAD); \
		[ -d "$(SEC_NLP_DIR)" ] && (cd "$(SEC_NLP_DIR)" && git fetch && git reset --hard origin/HEAD); \
	else \
		echo "No repositories found to update."; \
	fi

docker_build: docker_build_dev

docker_build_dev:
	@echo "Building Docker.dev"
	docker build -f Dockerfile.dev -t sec_poc_dev .
	docker build -f Dockerfile.ETL -t sec_poc_etl .

docker_build_prod:
	@echo "Building Docker.prod"
	docker buildx build --platform linux/amd64 -f Dockerfile.prod -t sec_poc_prod .
	docker build -f Dockerfile.ETL -t sec_poc_etl .

docker_compose: docker_compose_dev

docker_compose_dev:
	@echo "Composing docker-compose.dev.yml"
	docker-compose -f docker-compose.dev.yml -p sec_poc up -d

docker_compose_prod:
	@echo "Building docker-compose.prod.yml"
	docker-compose -f docker-compose.prod.yml -p sec_poc_prod up -d
