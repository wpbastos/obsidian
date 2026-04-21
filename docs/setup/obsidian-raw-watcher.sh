#!/usr/bin/env bash
# Watch the vault's .raw/ folder and auto-trigger Claude wiki-ingest on new sources.
# Debounces with a 10-second window — multiple files dropped together = one ingest.
#
# Configuration via env vars (or use defaults):
#   VAULT_PATH    - path to the Obsidian vault (required)
#   CLAUDE_BIN    - path to the claude binary (default: discovered via PATH)
#   FSWATCH_BIN   - path to the fswatch binary (default: discovered via PATH)
#
# Usage:
#   VAULT_PATH=~/Projects/_obsidian ./obsidian-raw-watcher.sh
#
# When run from a LaunchAgent, set these in the plist's EnvironmentVariables block.

set -u

if [ -z "${VAULT_PATH:-}" ]; then
    echo "ERROR: VAULT_PATH environment variable is not set" >&2
    exit 1
fi

# Expand ~ if present
VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

RAW_DIR="$VAULT_PATH/.raw"
LOG="$HOME/Library/Logs/obsidian-raw-watcher.log"
CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || echo "")}"
FSWATCH_BIN="${FSWATCH_BIN:-$(command -v fswatch 2>/dev/null || echo "")}"
LOCK="/tmp/obsidian-raw-watcher.lock"

if [ ! -d "$RAW_DIR" ]; then
    echo "ERROR: $RAW_DIR does not exist" >&2
    exit 1
fi
if [ -z "$CLAUDE_BIN" ] || [ ! -x "$CLAUDE_BIN" ]; then
    echo "ERROR: claude binary not found (set CLAUDE_BIN env var)" >&2
    exit 1
fi
if [ -z "$FSWATCH_BIN" ] || [ ! -x "$FSWATCH_BIN" ]; then
    echo "ERROR: fswatch binary not found (set FSWATCH_BIN env var; brew install fswatch)" >&2
    exit 1
fi

mkdir -p "$(dirname "$LOG")"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] watcher start (pid $$, vault=$VAULT_PATH)" >> "$LOG"

# -l 10 bundles events within a 10-second latency window.
# -0 uses NUL-separated output for safe filename handling.
"$FSWATCH_BIN" -l 10 -0 --event Created --event Renamed --event Updated "$RAW_DIR" \
| while IFS= read -r -d '' _; do
    # Skip if another ingest is still running.
    if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] event fired but ingest already running (pid $(cat "$LOCK")); skipping" >> "$LOG"
        continue
    fi

    # Enumerate eligible files via bash globbing (predictable; ignores mtime).
    # wiki-ingest's manifest dedupes already-processed files.
    shopt -s nullglob
    eligible=("$RAW_DIR"/*.md "$RAW_DIR"/*.pdf "$RAW_DIR"/*.txt "$RAW_DIR"/*.html \
              "$RAW_DIR"/*.MD "$RAW_DIR"/*.PDF)
    shopt -u nullglob

    if [ ${#eligible[@]} -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] event fired but no eligible files in .raw/" >> "$LOG"
        echo "  directory contents:" >> "$LOG"
        ls -la "$RAW_DIR" >> "$LOG" 2>&1 || true
        continue
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] eligible files in .raw/ (wiki-ingest will dedupe):" >> "$LOG"
    printf '  %s\n' "${eligible[@]}" >> "$LOG"
    files=$(printf '%s\n' "${eligible[@]}")

    # Claim the lock with our shell PID.
    echo "$$" > "$LOCK"
    trap 'rm -f "$LOCK"' EXIT

    # Run Claude headlessly; wiki-ingest skill triggers on the phrase.
    joined=$(echo "$files" | paste -sd, -)
    "$CLAUDE_BIN" -p --permission-mode bypassPermissions \
        "Run wiki-ingest on these files from .raw/: $joined. Check the manifest to skip already-processed files." \
        < /dev/null >> "$LOG" 2>&1 \
        || echo "[$(date '+%Y-%m-%d %H:%M:%S')] claude invocation failed" >> "$LOG"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ingest completed" >> "$LOG"
    rm -f "$LOCK"
done
