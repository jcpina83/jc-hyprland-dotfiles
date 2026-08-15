.PHONY: help doctor dry-run install apply tree lint waybar-test waybar-stop waybar-replace

help:
	@echo "jc-hyprland-dotfiles"
	@echo ""
	@echo "  make lint       	  Validate shell scripts"
	@echo "  make doctor     	  Check system dependencies"
	@echo "  make dry-run    	  Simulate installation"
	@echo "  make install    	  Install dotfiles"
	@echo "  make apply      	  Install and integrate Hyprland"
	@echo "  make tree       	  Show project structure"
	@echo "  make waybar-test     Start Odyssey Glass bars without killing existing Waybar"
	@echo "  make waybar-stop     Stop only Odyssey Glass bars"
	@echo "  make waybar-replace  Replace existing Waybar with Odyssey Glass"	

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

waybar-test:
	~/.config/jc-hyprland-dotfiles/bin/start-waybar.sh

waybar-stop:
	~/.config/jc-hyprland-dotfiles/bin/start-waybar.sh --stop

waybar-replace:
	~/.config/jc-hyprland-dotfiles/bin/start-waybar.sh --replace	