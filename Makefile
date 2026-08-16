.PHONY: help doctor dry-run install apply tree lint quickshell-validate quickshell-test waybar-test waybar-stop waybar-replace theme-list theme-current theme-apply wallpaper-apply theme-validate portability-check check release-check version install-check clean-install-check hypridle-configure

help:
	@echo "jc-hyprland-dotfiles"
	@echo ""
	@echo "  make lint       	  				Validate shell scripts"
	@echo "  make doctor     	  				Check system dependencies"
	@echo "  make dry-run    	  				Simulate installation"
	@echo "  make install    	  				Install dotfiles"
	@echo "  make apply      	  				Install and integrate Hyprland"
	@echo "  make tree       	  				Show project structure"
	@echo "  make quickshell-validate            Validate Quickshell structure and Phase 1A safety"
	@echo "  make quickshell-test                Check Quickshell IPC for the running shell"
	@echo "  make waybar-test     				Start Odyssey Glass bars without killing existing Waybar"
	@echo "  make waybar-stop     				Stop only Odyssey Glass bars"
	@echo "  make waybar-replace  				Replace existing Waybar with Odyssey Glass"	
	@echo "  theme-list                         List available themes"
	@echo "  theme-current                      Show active theme"
	@echo "  theme-apply THEME=<name>           Apply a theme"
	@echo "  wallpaper-apply                    Reapply active theme wallpapers"

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

quickshell-validate:
	./scripts/validate-quickshell.sh

quickshell-test:
	~/.config/jc-hyprland-dotfiles/bin/jc-control-center ipc-show

waybar-test:
	~/.config/jc-hyprland-dotfiles/bin/start-waybar.sh

waybar-stop:
	~/.config/jc-hyprland-dotfiles/bin/start-waybar.sh --stop

waybar-replace:
	~/.config/jc-hyprland-dotfiles/bin/start-waybar.sh --replace	

# ------------------------------------------------------------------------------
# Theme management
# ------------------------------------------------------------------------------

theme-list:
	~/.config/jc-hyprland-dotfiles/bin/jc-theme list

theme-current:
	~/.config/jc-hyprland-dotfiles/bin/jc-theme current

theme-apply:
	@test -n "$(THEME)" || (echo "Usage: make theme-apply THEME=<theme>"; exit 1)
	~/.config/jc-hyprland-dotfiles/bin/jc-theme apply "$(THEME)"

wallpaper-apply:
	~/.config/jc-hyprland-dotfiles/bin/apply-wallpaper.sh	

# ------------------------------------------------------------------------------
# Quality gates
# ------------------------------------------------------------------------------

theme-validate:
	./scripts/validate-themes.sh

portability-check:
	./scripts/portability-check.sh

check:
	@$(MAKE) --no-print-directory lint
	@$(MAKE) --no-print-directory doctor
	@echo
	@echo "All jc-hyprland-dotfiles checks passed."	

# ------------------------------------------------------------------------------
# Release
# ------------------------------------------------------------------------------

version:
	@cat VERSION

release-check:
	./scripts/release-check.sh	

install-check:
	@echo "==> Installer dry run"
	./scripts/install.sh --dry-run
	@echo
	@echo "Installer dry run passed."	

clean-install-check:
	./scripts/clean-install-check.sh	

hypridle-configure:
	./scripts/configure-hypridle.sh	