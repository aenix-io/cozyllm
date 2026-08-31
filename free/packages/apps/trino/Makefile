export NAME ?= trino
export NAMESPACE ?= cozy-trino

include ../../../scripts/package.mk

generate:
	cozyvalues-gen --values values.yaml --schema values.schema.json --readme README.md
