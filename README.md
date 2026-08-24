# Hardware Monitor Brightness

A lightweight, flicker-free hardware backlight brightness controller and multi-monitor manager for KDE Plasma 6.

---

## Overview

Most software-based brightness utilities on Linux adjust color lookup tables (gamma curves) on the GPU rather than communicating with the physical display. While this dims the screen, it degrades color accuracy, compresses dynamic range, and washes out contrast. Conversely, conventional DDC/CI utilities often poll monitors continuously in the background, saturating $\text{I}^2\text{C}$ buses and causing USB-C and DisplayPort MST docks to drop sync or flicker.

**Hardware Monitor Brightness** addresses both limitations:
- **Physical Backlight Regulation:** Adjusts physical monitor LED backlights directly via the VESA Display Data Channel Command Interface (DDC/CI).
- **Zero-Polling Architecture:** Never queries the display bus in the background. Bus transactions occur exclusively when a user adjusts a slider or scrolls on the widget icon.
- **Asynchronous Execution:** Uses a non-blocking background daemon with file locking to coalesce rapid user inputs and prevent GPU bus contention.

---

## Features

- **Direct Hardware DDC/CI Control:** Adjusts monitor backlight registers (`VCP Code 10`) for full color fidelity and contrast preservation.
- **Master and Per-Display Sliders:** Simultaneously adjust all connected screens via the master slider and quick presets (25%, 50%, 75%, 100%), or adjust individual monitors independently.
- **Taskbar Mouse Wheel Control:** Scroll over the panel icon to adjust brightness in configurable step increments.
- **Dynamic Adaptive Icon:** Vector symbolic icon that automatically adapts to dark, light, and custom desktop color schemes.
- **Configurable Settings:** Customize adjustment step sizes (1% to 25%), toggle taskbar percentage badges, invert scroll directions, and configure multi-monitor layouts.
- **Instant On-Screen Display (OSD):** Triggers KDE Plasma's native brightness overlay seamlessly via D-Bus.

---

## Requirements

The widget requires `ddcutil` to communicate with external monitors over $\text{I}^2\text{C}$.

### 1. Install `ddcutil`

- **Arch Linux / Manjaro:**
  ```bash
  sudo pacman -S ddcutil
  ```
- **Fedora / RHEL:**
  ```bash
  sudo dnf install ddcutil
  ```
- **Ubuntu / Debian:**
  ```bash
  sudo apt install ddcutil
  ```

### 2. Configure Permissions

Ensure your user account belongs to the `i2c` group to access $\text{I}^2\text{C}$ device nodes without root privileges:

```bash
sudo usermod -aG i2c $USER
```

*(Log out and log back in for group membership changes to take effect).*

---

## Installation

### Method 1: KDE Store (Recommended)

1. Right-click the KDE panel and select **Add Widgets...**
2. Click **Get New Widgets...** $\rightarrow$ **Download New Plasma Widgets**.
3. Search for **Hardware Monitor Brightness** and click **Install**.

---

### Method 2: Manual Installation

```bash
# Clone repository
git clone https://github.com/shrektech/hardware-monitor-brightness.git
cd hardware-monitor-brightness

# Install plasmoid package
kpackagetool6 -t Plasma/Applet -i .

# Restart Plasma shell
systemctl --user restart plasma-plasmashell.service
```

---

## Keyboard Shortcuts & CLI Usage

Brightness adjustments can be triggered from custom keyboard shortcuts or terminal scripts using the bundled worker script:

```bash
# Increase / decrease by 5%
~/.local/share/plasma/plasmoids/org.custom.hardwarebrightness/contents/scripts/brightness-worker.py +5
~/.local/share/plasma/plasmoids/org.custom.hardwarebrightness/contents/scripts/brightness-worker.py -5

# Set absolute percentage
~/.local/share/plasma/plasmoids/org.custom.hardwarebrightness/contents/scripts/brightness-worker.py set 75
```

---

## License

This project is licensed under the **GNU General Public License v3.0 or later** ([GPL-3.0-or-later](LICENSE)).
