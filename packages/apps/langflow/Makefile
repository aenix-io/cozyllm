export NAME ?= langflow
export NAMESPACE ?= cozy-langflow

include ../../../scripts/package.mk

generate:
	cozyvalues-gen --values values.yaml --schema values.schema.json --readme README.md
