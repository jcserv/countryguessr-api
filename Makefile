.PHONY: setup deps compile test format lint run build docker.build docker.run clean

# Development
setup: deps
	@echo "Setup complete!"

deps:
	mix deps.get

compile:
	mix compile

test:
	mix test

format:
	mix format

lint:
	mix credo --strict

run:
	iex -S mix phx.server

# Alias for run
dev: run

# Production build
build:
	MIX_ENV=prod mix release

# Docker
docker.build:
	docker build -t counter:latest .

docker.run:
	docker run -p 4000:4000 \
		-e SECRET_KEY_BASE="dev_secret_at_least_64_bytes_long_for_docker_testing_purposes" \
		-e PHX_HOST=localhost \
		-e PORT=4000 \
		counter:latest

docker.up:
	docker-compose up -d

docker.down:
	docker-compose down

# Cleanup
clean:
	rm -rf _build deps

# CI
ci: deps compile format lint test
	@echo "CI checks passed!"

# Generate secret
secret:
	mix phx.gen.secret

# Help
help:
	@echo "Available commands:"
	@echo "  make setup       - Install dependencies"
	@echo "  make dev         - Start development server"
	@echo "  make test        - Run tests"
	@echo "  make format      - Format code"
	@echo "  make lint        - Run Credo linter"
	@echo "  make build       - Build production release"
	@echo "  make docker.build - Build Docker image"
	@echo "  make docker.run   - Run Docker container"
	@echo "  make ci          - Run all CI checks"
