#!/usr/bin/env bash
# Install a SIGNED 3105 IPA onto a USB-connected device.
# Usage: ./scripts/install-ipa.sh <signed.ipa>
set -euo pipefail

IPA="${1:?usage: install-ipa.sh <signed.ipa>}"
[ -f "$IPA" ] || { echo "error: IPA not found: $IPA" >&2; exit 1; }

if [ "$(uname -s)" != "Darwin" ]; then
  echo "error: device installation tooling here requires macOS." >&2
  exit 1
fi

if command -v cfgutil >/dev/null 2>&1; then
  echo "==> Apple Configurator: cfgutil install-ipa"
  cfgutil install-ipa "$IPA"
elif command -v ideviceinstaller >/dev/null 2>&1; then
  echo "==> libimobiledevice: ideviceinstaller -i"
  ideviceinstaller -i "$IPA"
else
  cat >&2 <<'EOF'
error: no device installer found. Pick one:
  * Apple Configurator 2 > menu "Install Automation Tools" (provides cfgutil)
  * brew install libimobiledevice   (provides ideviceinstaller)
For MDM / enterprise distribution, upload the signed IPA to your MDM or HTTPS
host instead of using this script.
EOF
  exit 1
fi

echo "==> Install requested. If the device asks to trust the developer:"
echo "    Settings > General > VPN & Device Management > <Enterprise> > Trust"
