# Korting-OS (Raspberry Pi Kiosk OS)

This repository provides a **turnkey Raspberry Pi kiosk build** that:

- boots directly to a branded splash/logo,
- auto-launches a browser in full-screen kiosk mode,
- opens the website URL you set,
- disables screen blanking / sleep so the screen stays on.

> This is implemented as a hardened configuration layer on top of Raspberry Pi OS, so you can reproduce and version-control your kiosk image.

## What it does

The installer configures:

1. **Auto-login on graphical boot** (LightDM + Openbox)
2. **Kiosk browser startup** (Chromium first, Firefox fallback)
3. **Crash restart watchdog** (systemd service)
4. **Custom boot splash/logo** (`/opt/kiosk/logo.png` shown on tty1 during boot)
5. **No blanking / no sleep**
   - X11 screensaver off
   - DPMS off
   - console blank disabled
   - system sleep/suspend/hibernate masked
   - HDMI forced active
6. **Text-only placeholder splash asset** (no binary files in repo)

## Prerequisites

- Raspberry Pi 3/4/5
- Fresh install of Raspberry Pi OS (Bookworm, desktop recommended)
- Internet access for package install
- Run commands as `root` or with `sudo`

## Install

From this repo on the Pi:

```bash
sudo bash scripts/install-kiosk-os.sh
```

Then set your kiosk URL:

```bash
sudo kioskctl set-url https://your-kiosk-site.example
```

Optional: force browser choice:

```bash
sudo kioskctl set-browser chromium
# or
sudo kioskctl set-browser firefox
# or
sudo kioskctl set-browser auto
```

Replace the logo image:

```bash
sudo cp /path/to/your-logo.png /opt/kiosk/logo.png
```

> The repo ships a text-format placeholder image (`assets/placeholder-logo.ppm`) so PR tooling that blocks binary files will still work.

Reboot:

```bash
sudo reboot
```

## Day-2 Operations

Show current config:

```bash
kioskctl show
```

Config files:

- URL: `/etc/kiosk/url.conf`
- Browser preference: `/etc/kiosk/browser.conf`
- Logo: `/opt/kiosk/logo.png`

Systemd units installed:

- `kiosk-splash.service`
- `kiosk-browser.service`

## Notes

- If your panel still power-saves on its own, disable sleep in the panel's OSD/firmware.
- Chromium is the default because it is generally the most stable option for Pi kiosk deployments.
- For production, pair this with a read-only root filesystem and remote management if needed.
