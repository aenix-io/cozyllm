export NAME ?= lakehouse
export NAMESPACE ?= cozy-lakehouse

include ../../../scripts/package.mk

generate:
	cozyvalues-gen --values values.yaml --schema values.schema.json --readme README.md
