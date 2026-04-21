#!/usr/bin/env bash
# Install the auto-ingest watcher as a macOS LaunchAgent.
# Substitutes {{HOME}} and {{VAULT_PATH}} in the plist template, copies files
# to their target locations, and loads the LaunchAgent.
#
# Usage:
#   ./install-watcher.sh                     # uses VAULT_PATH from env or current dir
#   VAULT_PATH=~/Projects/_obsidian ./install-watcher.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VAULT_PATH="${VAULT_PATH:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

if [ ! -d "$VAULT_PATH/.raw" ]; then
    echo "ERROR: $VAULT_PATH/.raw not found — is VAULT_PATH correct?" >&2
    exit 1
fi

# Verify dependencies
command -v fswatch >/dev/null || { echo "ERROR: fswatch not installed (brew install fswatch)" >&2; exit 1; }
command -v claude >/dev/null || { echo "ERROR: claude CLI not installed" >&2; exit 1; }

mkdir -p "$HOME/bin" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"

# Install the watcher script
cp "$SCRIPT_DIR/obsidian-raw-watcher.sh" "$HOME/bin/obsidian-raw-watcher.sh"
chmod +x "$HOME/bin/obsidian-raw-watcher.sh"
echo "Installed: $HOME/bin/obsidian-raw-watcher.sh"

# Substitute placeholders in the plist
PLIST_PATH="$HOME/Library/LaunchAgents/com.obsidian-vault.raw-watcher.plist"
sed -e "s|{{HOME}}|$HOME|g" \
    -e "s|{{VAULT_PATH}}|$VAULT_PATH|g" \
    "$SCRIPT_DIR/com.obsidian-vault.raw-watcher.plist.template" > "$PLIST_PATH"
echo "Installed: $PLIST_PATH"

# Reload (unload first if it's already loaded)
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"
echo "LaunchAgent loaded."

# Status check
sleep 1
if launchctl list | grep -q "com.obsidian-vault.raw-watcher"; then
    echo
    echo "Watcher is running."
    echo "Drop a .md/.pdf/.txt/.html file into $VAULT_PATH/.raw/ to test."
    echo "Tail the log: tail -f $HOME/Library/Logs/obsidian-raw-watcher.log"
else
    echo "WARNING: LaunchAgent did not start. Check $HOME/Library/Logs/obsidian-raw-watcher.err.log" >&2
    exit 1
fi
