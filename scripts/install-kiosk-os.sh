#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0" >&2
  exit 1
fi

KIOSK_USER="${SUDO_USER:-pi}"
KIOSK_GROUP="$(id -gn "${KIOSK_USER}" 2>/dev/null || echo "${KIOSK_USER}")"
KIOSK_URL_DEFAULT="https://example.com"

if ! id "${KIOSK_USER}" >/dev/null 2>&1; then
  echo "User ${KIOSK_USER} does not exist. Create the user first." >&2
  exit 1
fi

echo "[1/8] Installing dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  chromium-browser \
  firefox-esr \
  xserver-xorg \
  x11-xserver-utils \
  xinit \
  openbox \
  lightdm \
  unclutter \
  fbi

echo "[2/8] Installing kiosk launcher tools..."
install -m 0755 usr-local-bin/kiosk-launch-browser.sh /usr/local/bin/kiosk-launch-browser
install -m 0755 usr-local-bin/kioskctl.sh /usr/local/bin/kioskctl

mkdir -p /etc/kiosk
if [[ ! -f /etc/kiosk/url.conf ]]; then
  echo "${KIOSK_URL_DEFAULT}" > /etc/kiosk/url.conf
fi

if [[ ! -f /etc/kiosk/browser.conf ]]; then
  echo "auto" > /etc/kiosk/browser.conf
fi

mkdir -p /opt/kiosk
if [[ ! -f /opt/kiosk/logo.png && ! -f /opt/kiosk/logo.ppm ]]; then
  cp assets/placeholder-logo.ppm /opt/kiosk/logo.ppm
fi

chown -R "${KIOSK_USER}:${KIOSK_GROUP}" /opt/kiosk

echo "[3/8] Configuring autologin + session startup..."
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/40-kiosk.conf <<LIGHTDM
[Seat:*]
autologin-user=${KIOSK_USER}
autologin-user-timeout=0
user-session=openbox
xserver-command=X -s 0 -dpms
LIGHTDM

install -d -m 0755 -o "${KIOSK_USER}" -g "${KIOSK_GROUP}" "/home/${KIOSK_USER}/.config/openbox"
cat > "/home/${KIOSK_USER}/.config/openbox/autostart" <<'AUTOSTART'
#!/usr/bin/env bash
xset s off
xset -dpms
xset s noblank
unclutter -idle 0.5 -root &
/usr/local/bin/kiosk-launch-browser &
AUTOSTART
chmod 0755 "/home/${KIOSK_USER}/.config/openbox/autostart"
chown "${KIOSK_USER}:${KIOSK_GROUP}" "/home/${KIOSK_USER}/.config/openbox/autostart"

echo "[4/8] Installing splash service for custom logo..."
install -m 0644 systemd/kiosk-splash.service /etc/systemd/system/kiosk-splash.service

echo "[5/8] Installing browser service (restarts browser if it crashes)..."
sed "s/__KIOSK_USER__/${KIOSK_USER}/g" systemd/kiosk-browser.service > /etc/systemd/system/kiosk-browser.service
chmod 0644 /etc/systemd/system/kiosk-browser.service

systemctl daemon-reload
systemctl enable kiosk-splash.service
systemctl enable kiosk-browser.service
systemctl set-default graphical.target

echo "[6/8] Disabling screen blanking and sleep..."
if grep -q 'consoleblank=' /boot/firmware/cmdline.txt 2>/dev/null; then
  sed -i 's/consoleblank=[0-9]\+/consoleblank=0/g' /boot/firmware/cmdline.txt
elif [[ -f /boot/firmware/cmdline.txt ]]; then
  sed -i '1 s/$/ consoleblank=0/' /boot/firmware/cmdline.txt
elif [[ -f /boot/cmdline.txt ]]; then
  if grep -q 'consoleblank=' /boot/cmdline.txt; then
    sed -i 's/consoleblank=[0-9]\+/consoleblank=0/g' /boot/cmdline.txt
  else
    sed -i '1 s/$/ consoleblank=0/' /boot/cmdline.txt
  fi
fi

if [[ -f /etc/kbd/config ]]; then
  sed -i 's/^BLANK_TIME=.*/BLANK_TIME=0/' /etc/kbd/config || true
  sed -i 's/^POWERDOWN_TIME=.*/POWERDOWN_TIME=0/' /etc/kbd/config || true
fi

systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

echo "[7/8] Forcing HDMI to stay active..."
BOOT_CONFIG=""
if [[ -f /boot/firmware/config.txt ]]; then
  BOOT_CONFIG="/boot/firmware/config.txt"
elif [[ -f /boot/config.txt ]]; then
  BOOT_CONFIG="/boot/config.txt"
fi

if [[ -n "${BOOT_CONFIG}" ]]; then
  grep -q '^hdmi_force_hotplug=1' "${BOOT_CONFIG}" || echo 'hdmi_force_hotplug=1' >> "${BOOT_CONFIG}"
  grep -q '^hdmi_blanking=1' "${BOOT_CONFIG}" || echo 'hdmi_blanking=1' >> "${BOOT_CONFIG}"
fi

echo "[8/8] Final output"
cat <<MSG
Kiosk OS configuration complete.

Next steps:
1) Set your URL:
   sudo kioskctl set-url https://your-site.example
2) Replace logo:
   sudo cp /path/to/your-logo.png /opt/kiosk/logo.png
3) Reboot:
   sudo reboot
MSG
