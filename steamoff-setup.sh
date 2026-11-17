#!/bin/bash
# SteamOff for macOS. Usage: bash steamoff-setup.sh install|status|uninstall
set -euo pipefail

LABEL='local.steamoff.event'
IPC_SERVICE='com.valvesoftware.steam.ipctool'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWIFT_SOURCE="$SCRIPT_DIR/Sources/SteamQuit.swift"
DEST_SOURCE="$HOME/.local/share/steamoff/SteamQuit.swift"
DEST_BINARY="$HOME/.local/bin/steamoff-event"
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/steamoff-event.log"
ERROR_LOG="$HOME/Library/Logs/steamoff-event-errors.log"
DOMAIN="gui/$(id -u)"

if [[ "$(uname -s)" != Darwin ]]; then
    echo 'SteamOff supports macOS only.' >&2
    exit 1
fi
if [[ "$(id -u)" -eq 0 ]]; then
    echo 'Run as your normal macOS user. Do not use sudo.' >&2
    exit 1
fi

require_gui() {
    if ! launchctl print "$DOMAIN" >/dev/null 2>&1; then
        echo 'Open Terminal in your signed-in Mac desktop and retry (not SSH).' >&2
        exit 1
    fi
}

xml_escape() {
    printf '%s' "$1" | sed -e 's/\&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

install() {
    require_gui
    if [[ ! -f "$SWIFT_SOURCE" ]]; then
        echo "Missing $SWIFT_SOURCE. Download or clone the whole repository." >&2
        exit 1
    fi
    if ! command -v xcrun >/dev/null 2>&1 || ! xcrun --find swiftc >/dev/null 2>&1; then
        echo 'Swift compiler missing. Install Xcode Command Line Tools:' >&2
        echo '  xcode-select --install' >&2
        exit 1
    fi

    mkdir -p "$(dirname "$DEST_SOURCE")" "$(dirname "$DEST_BINARY")" \
        "$(dirname "$AGENT")" "$(dirname "$LOG")"

    local temp_binary temp_agent
    temp_binary="$DEST_BINARY.tmp.$$"
    temp_agent="$AGENT.tmp.$$"
    trap 'rm -f "$temp_binary" "$temp_agent"' EXIT

    echo 'Compiling the listener for this Mac…'
    xcrun swiftc -O "$SWIFT_SOURCE" -o "$temp_binary"
    chmod 700 "$temp_binary"

    cat > "$temp_agent" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$LABEL</string>
    <key>ProgramArguments</key>
    <array><string>$(xml_escape "$DEST_BINARY")</string></array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>StandardOutPath</key><string>$(xml_escape "$LOG")</string>
    <key>StandardErrorPath</key><string>$(xml_escape "$ERROR_LOG")</string>
</dict>
</plist>
EOF
    plutil -lint "$temp_agent"
    chmod 600 "$temp_agent"

    if launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; then
        echo 'Replacing existing SteamOff listener…'
        launchctl bootout "$DOMAIN/$LABEL"
    fi

    cp "$SWIFT_SOURCE" "$DEST_SOURCE"
    mv -f "$temp_binary" "$DEST_BINARY"
    mv -f "$temp_agent" "$AGENT"
    trap - EXIT

    if ! launchctl bootstrap "$DOMAIN" "$AGENT"; then
        echo 'The listener could not start. Inspect the error above.' >&2
        exit 1
    fi
    launchctl print "$DOMAIN/$LABEL" >/dev/null
    echo 'Installed. SteamOff now listens for Steam termination events.'
    echo 'No timer, administrator privileges, or changes to Steam files.'
    echo "Log: $LOG"
}

status() {
    echo '=== SteamOff listener ==='
    if launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; then
        launchctl print "$DOMAIN/$LABEL" | grep -E 'state =|runs =|last exit code =' || true
    else
        echo 'Not registered'
    fi
    echo '=== Steam processes ==='
    pgrep -fl 'steam_osx|ipcserver|Steam Helper' || echo 'None'
    echo '=== Steam IPC service ==='
    launchctl list | grep -F "$IPC_SERVICE" || echo 'Not loaded'
    echo '=== Recent log ==='
    if [[ -f "$LOG" ]]; then tail -n 12 "$LOG"; else echo 'No log yet'; fi
    if [[ -s "$ERROR_LOG" ]]; then
        echo '=== Errors ==='
        tail -n 8 "$ERROR_LOG"
    fi
}

uninstall() {
    require_gui
    if launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; then
        launchctl bootout "$DOMAIN/$LABEL"
    fi
    rm -f "$AGENT" "$DEST_BINARY" "$DEST_SOURCE" "$LOG" "$ERROR_LOG"
    rmdir "$(dirname "$DEST_SOURCE")" 2>/dev/null || true
    echo 'SteamOff uninstalled. Steam and its files are unchanged.'
}

case "${1:-install}" in
    install) install ;;
    status) status ;;
    uninstall) uninstall ;;
    *) echo 'Usage: bash steamoff-setup.sh [install|status|uninstall]' >&2; exit 2 ;;
esac
