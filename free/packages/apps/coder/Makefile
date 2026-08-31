export NAME ?= coder
export NAMESPACE ?= cozy-coder

include ../../../scripts/package.mk

generate:
	cozyvalues-gen --values values.yaml --schema values.schema.json --readme README.md
