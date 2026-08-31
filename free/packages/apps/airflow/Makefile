export NAME ?= airflow
export NAMESPACE ?= cozy-airflow

include ../../../scripts/package.mk

generate:
	cozyvalues-gen --values values.yaml --schema values.schema.json --readme README.md
