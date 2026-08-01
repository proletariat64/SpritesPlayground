SHELL := /bin/bash

.PHONY: help doc-check doc-guard fake-check fake-check-test agent-docs lint test release-check

help:
	@echo "Available commands:"
	@echo "  make help          Show this help"
	@echo "  make doc-check     Run local documentation checks"
	@echo "  make doc-guard     Run Doc Watch Guard report"
	@echo "  make fake-check    Run AI fake-completion implementation guard"
	@echo "  make agent-docs    Print a safe agent documentation review prompt"
	@echo "  make lint          Compile-check project Python automation"
	@echo "  make test          Run project Python behavior tests"
	@echo "  make release-check Run documentation release checks"

doc-check:
	@./scripts/doc-check-local.sh

doc-guard:
	@./scripts/doc-guard.sh

fake-check:
	@./scripts/fake-implementation-guard.sh

fake-check-test:
	@./scripts/test-fake-implementation-guard.sh

agent-docs:
	@./scripts/agent-doc-review.sh

lint:
	@python3 -m py_compile ./scripts/*.py ./tests/*.py ./.github/workflows/scripts/*.py

test:
	@python3 -m unittest discover -s tests -p 'test_*.py' -v

release-check: doc-check doc-guard fake-check lint test
