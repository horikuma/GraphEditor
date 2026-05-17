SHELL := /bin/bash

.PHONY: build launch inspect collect show

build:
	@./scripts/build.sh

launch:
	@./scripts/launch.sh

inspect:
	@case "$(word 2,$(MAKECMDGOALS))" in \
		"") ./scripts/inspect/collect.sh && ./scripts/inspect/views.sh;; \
		collect) ./scripts/inspect/collect.sh;; \
		show) ./scripts/inspect/views.sh;; \
		*) echo "Usage: make inspect collect|show" >&2; exit 2;; \
	esac

collect show:
	@:
