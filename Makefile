.PHONY: help doctor dry-run install apply tree lint

help:
	@echo "jc-hyprland-dotfiles"
	@echo ""
	@echo "  make lint       Validate shell scripts"
	@echo "  make doctor     Check system dependencies"
	@echo "  make dry-run    Simulate installation"
	@echo "  make install    Install dotfiles"
	@echo "  make apply      Install and integrate Hyprland"
	@echo "  make tree       Show project structure"

doctor:
	./scripts/doctor.sh

dry-run:
	./install.sh --dry-run

install:
	./install.sh

apply:
	./install.sh --apply-hyprland

tree:
	./scripts/show-structure.sh 4

lint:
	./scripts/lint.sh