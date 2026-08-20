export NAME ?= comfyui
export NAMESPACE ?= cozy-comfyui

include ../../../scripts/package.mk

generate:
	cozyvalues-gen --values values.yaml --schema values.schema.json --readme README.md
