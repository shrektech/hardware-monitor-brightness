# ☀️ Luminar

> **Hardware Monitor Brightness Controller for KDE Plasma 6**  
> *Flicker-free, zero-polling DDC/CI physical LED backlight control & multi-monitor manager.*

---

## 🌟 Why Luminar?

Standard desktop brightness tools on Linux often suffer from two major problems:
1. **Software Gamma Dimming:** They adjust pixel color curves on the GPU rather than physical backlights, degrading contrast and washing out colors.
2. **Dock Flickering:** Continuous background $\text{I}^2\text{C}$ polling loops saturate DisplayPort AUX channels on USB-C and MST docks, causing external screens to blink or drop sync.

**Luminar solves both.** It provides a lightweight, responsive, and robust hardware brightness control built natively for **KDE Plasma 6**.

---

## ✨ Features

- 💡 **Pure Hardware DDC/CI:** Directly adjusts the physical LED backlight registers (`VCP 10`) of your monitors—100% full uncompressed color dynamic range.
- 🚫 **Zero-Polling / Flicker-Free:** Never spammed across the $\text{I}^2\text{C}$ bus. The bus stays completely silent until you touch a slider or scroll.
- 🎛️ **Master & Individual Sliders:** Adjust all screens together with the Master slider and quick presets (`25%`, `50%`, `75%`, `100%`), or adjust each monitor independently by model name.
- 🖱️ **Taskbar Mouse-Wheel Scroll:** Scroll directly on the taskbar icon to step brightness up or down.
- 🚀 **0ms Instant OSD:** Asynchronous, non-blocking background worker with file locking (`flock`) to coalesce rapid user inputs safely.
- 🎨 **Adaptive Symbolic Icon:** Native KDE vector icon that dynamically adapts to dark, light, and custom desktop themes.
- ⚙️ **KDE Settings Integration:** Configurable step size ($1\%-25\%$), optional taskbar percentage badge, scroll inversion, and popup layout controls.

---

## 📦 Installation

### Option 1: Via KDE Store (Recommended)
1. Right-click your KDE panel $\rightarrow$ **Add Widgets...**
2. Click **Get New Widgets...** $\rightarrow$ Search for **`Luminar`**.
3. Click **Install**.

---

### Option 2: Manual Installation from Source
```bash
# 1. Clone repository
git clone https://github.com/shrektech/luminar.git
cd luminar

# 2. Install widget package for KDE Plasma 6
kpackagetool6 -t Plasma/Applet -i .

# 3. Reload Plasma shell
systemctl --user restart plasma-plasmashell.service
```

---

## 🔧 Prerequisites

Luminar communicates with external displays using standard VESA DDC/CI via `ddcutil`.

1. **Install `ddcutil`:**
   ```bash
   # Arch Linux / Manjaro
   sudo pacman -S ddcutil

   # Fedora / RHEL
   sudo dnf install ddcutil

   # Ubuntu / Debian
   sudo apt install ddcutil
   ```

2. **Ensure your user is in the `i2c` group:**
   ```bash
   sudo usermod -aG i2c $USER
   ```
   *(Log out and log back in for group permissions to take effect).*

---

## 📄 License

Luminar is licensed under the **GNU General Public License v3.0 or later** ([GPL-3.0-or-later](LICENSE)).
