export NAME ?= open-webui
export NAMESPACE ?= cozy-open-webui

include ../../../scripts/package.mk

generate:
	cozyvalues-gen --values values.yaml --schema values.schema.json --readme README.md
