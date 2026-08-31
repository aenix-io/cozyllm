export NAME ?= sparkcluster
export NAMESPACE ?= cozy-sparkcluster

include ../../../scripts/package.mk

generate:
	cozyvalues-gen --values values.yaml --schema values.schema.json --readme README.md
