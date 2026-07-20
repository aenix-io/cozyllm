export NAME ?= jupyterhub
export NAMESPACE ?= cozy-jupyterhub

include ../../../scripts/package.mk

generate:
	cozyvalues-gen --values values.yaml --schema values.schema.json --readme README.md
