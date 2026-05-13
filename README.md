# OpenTrackerBar

[DankMaterialShell](https://github.com/DankMaterialShell/DankMaterialShell) plugin that tracks OpenCode.ai usage limits via the [opentracker](https://github.com/wsmajt/opentracker) CLI.

## Requirements

- [opentracker-cli](https://aur.archlinux.org/packages/opentracker-cli): `yay -S opentracker-cli`

## Install

```bash
git clone https://github.com/wsmajt/OpenTrackerBar.git ~/.config/DankMaterialShell/plugins/OpenTrackerBar
```

## Setup

```bash
opentracker login opencode
# Log in via browser, export Netscape cookies to ~/.config/opentracker/opencode-cookies.txt
opentracker fetch opencode-go
# First run will prompt for your workspace ID
```

## Usage

Enable the `OpenTrackerBar` plugin in DankMaterialShell settings.
