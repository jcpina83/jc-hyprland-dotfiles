.PHONY: doctor dry-run install apply tree

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
