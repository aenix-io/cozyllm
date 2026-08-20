export NAME ?= n8n
export NAMESPACE ?= cozy-n8n

include ../../../scripts/package.mk

generate:
	cozyvalues-gen --values values.yaml --schema values.schema.json --readme README.md
