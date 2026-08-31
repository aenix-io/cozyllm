export NAME ?= mlflow
export NAMESPACE ?= cozy-mlflow

include ../../../scripts/package.mk

generate:
	cozyvalues-gen --values values.yaml --schema values.schema.json --readme README.md
