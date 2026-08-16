#!/usr/bin/env bash

set -euo pipefail

# Allow the input event that triggered Suspend (for example, a mouse click
# from nwgbar) to settle before entering system sleep.
sleep 1

exec systemctl suspend