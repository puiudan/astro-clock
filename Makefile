.DEFAULT_GOAL := help
.PHONY: help status configure menuconfig savedefconfig build

help status configure menuconfig savedefconfig build:
	@./scripts/buildroot $@
