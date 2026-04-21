# Obsidian Claude Memory Vault

A personal **second brain** + **shared knowledge base** for Claude Code, built as an Obsidian vault. Drop sources into `.raw/`, Claude ingests them into a curated wiki, and any Claude Code project can query the accumulated knowledge.

Inspired by Karpathy's [LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) and adapted from [AgriciDaniel/claude-obsidian](https://github.com/AgriciDaniel/claude-obsidian).

---

## What it does

- **Capture** — `/save` files the current conversation as a wiki note
- **Ingest** — drop a file in `.raw/`, run `ingest [file]`, and Claude extracts 8-15 cross-linked wiki pages
- **Auto-ingest** — fswatch + LaunchAgent watches `.raw/` and triggers ingest on every new file (no manual command)
- **Query** — `what do you know about X?` reads the wiki and synthesizes an answer with citations
- **Lint** — `/wiki-lint` finds orphans, dead links, stale claims, and refreshes the always-loaded `hot.md`

Auto-memory is disabled at user scope. All knowledge capture is intentional.

---

## Setup

### 1. Clone the vault

```bash
git clone <repo> ~/Projects/_obsidian
cd ~/Projects/_obsidian
```

### 2. Install required Obsidian community plugins

Open the vault in Obsidian, then in **Settings → Community plugins**, install + enable:

- **Templater** (template variable interpolation in `_templates/`)
- **Local REST API** (required for the `mcp-obsidian` MCP server)

Set Templater's template folder to `_templates/`.

### 3. Install user-scope Claude Code skills

The 7 skills live at `~/.claude/skills/`. Until packaged as a plugin, install manually:

```bash
# 3 utility skills from kepano/obsidian-skills (MIT)
git clone https://github.com/kepano/obsidian-skills /tmp/kepano
cp -r /tmp/kepano/skills/{obsidian-markdown,obsidian-bases,defuddle} ~/.claude/skills/

# 4 wiki skills adapted from AgriciDaniel/claude-obsidian (MIT)
# These have local adaptations — copy from this repo's accompanying skill bundle
# (see docs/superpowers/specs/2026-04-20-claude-memory-vault-design.md for the source paths)
```

> Future: see [`docs/NOTES.md`](docs/NOTES.md) for the planned plugin packaging that will replace step 3.

### 4. Configure user-scope Claude Code

```bash
# Disable per-project auto-memory (one-time, in ~/.claude/settings.json)
python3 -c "
import json, pathlib
p = pathlib.Path.home() / '.claude/settings.json'
d = json.loads(p.read_text()) if p.exists() else {}
d['autoMemoryEnabled'] = False
p.write_text(json.dumps(d, indent=2))
"

# Append the vault pointer to ~/.claude/CLAUDE.md (idempotent)
grep -q '<!-- obsidian-vault-pointer:v1 -->' ~/.claude/CLAUDE.md 2>/dev/null || cat >> ~/.claude/CLAUDE.md <<'EOF'
<!-- obsidian-vault-pointer:v1 -->
## Obsidian Knowledge Vault

Vault path: ~/Projects/_obsidian

For non-trivial work, at session start:
1. Read wiki/hot.md (always) — recent context, ~500 words
2. If not enough, read wiki/index.md — catalog of all pages
3. Drill into subdomain folders as needed
4. Do NOT read the wiki for general coding questions already
   answered in-project or trivial tasks.

Capture: run /save at session end to file useful takeaways
as a wiki note. Drop sources into .raw/ and run "ingest [file]"
to promote them into the wiki.
EOF
```

### 5. Install the `mcp-obsidian` MCP server

```bash
claude mcp add obsidian-vault -- uvx mcp-obsidian
```

You'll be prompted for the Obsidian Local REST API key (Settings → Local REST API in Obsidian).

### 6. (Optional) Set up auto-ingest watcher

```bash
brew install fswatch
cd docs/setup
./install-watcher.sh
```

The installer:
- Copies `docs/setup/obsidian-raw-watcher.sh` → `~/bin/obsidian-raw-watcher.sh`
- Substitutes `{{HOME}}` and `{{VAULT_PATH}}` in `docs/setup/com.obsidian-vault.raw-watcher.plist.template` → `~/Library/LaunchAgents/com.obsidian-vault.raw-watcher.plist`
- Loads the LaunchAgent (auto-starts at login, KeepAlive)

After install, drop a `.md`/`.pdf`/`.txt`/`.html` file into `.raw/` and tail `~/Library/Logs/obsidian-raw-watcher.log` to see ingest fire.

To stop: `launchctl unload ~/Library/LaunchAgents/com.obsidian-vault.raw-watcher.plist`

---

## Daily use

| Action | Command (anywhere in Claude Code) |
|---|---|
| Save current conversation | `/save` or `save this to the wiki` |
| Save with a title | `/save my-note-title` |
| Ingest a single source | drop in `.raw/`, then `ingest [file]` (or do nothing if watcher is on) |
| Ingest a URL | `ingest this URL: https://...` |
| Batch ingest | drop multiple files, then `ingest all of these` |
| Ask the wiki | `what do you know about X?` or `query: X` |
| Health check | `/wiki-lint` or `lint the wiki` |
| Refresh hot cache | `update hot cache` |

Cross-project: from any Claude Code project, the same commands work because the skills are user-scoped and the user CLAUDE.md points every session at this vault.

---

## Architecture

```
~/Projects/_obsidian/
├── .raw/                       ← drop sources here (ignored from search/graph)
├── wiki/
│   ├── index.md                ← catalog
│   ├── hot.md                  ← always-loaded session context
│   ├── log.md                  ← append-only ingest/save/lint trail
│   ├── overview.md             ← exec summary of vault
│   ├── concepts/               ← ideas, patterns, techniques
│   ├── entities/               ← people, tools, libraries
│   ├── sources/                ← articles, talks
│   ├── journal/                ← personal reflections
│   ├── projects/               ← per-codebase wiki pages
│   ├── architectures/          ← codebase-level design notes
│   ├── papers/                 ← academic papers with citations
│   ├── questions/              ← open questions
│   ├── comparisons/            ← side-by-side analyses
│   └── meta/dashboard.base     ← Obsidian Bases dashboard
├── _templates/                 ← Templater templates (9 note types)
├── _attachments/               ← images, PDFs
├── CLAUDE.md                   ← vault-scoped rules for Claude
├── docs/
│   ├── NOTES.md                ← future work, open items, verified-working checklist
│   └── superpowers/specs/      ← design spec
└── .obsidian/                  ← Obsidian config (app.json, snippets, etc.)
```

---

## Skills (user-scoped at `~/.claude/skills/`)

| Skill | Trigger | What it does |
|---|---|---|
| `save` | `/save`, "save this" | Files current conversation as a wiki note |
| `wiki-ingest` | `ingest [file]` | Reads `.raw/`, extracts pages, cross-links |
| `wiki-query` | "what do you know about X?" | Searches wiki, synthesizes with citations |
| `wiki-lint` | `/wiki-lint` | Finds orphans, dead links, refreshes `hot.md` |
| `obsidian-markdown` | on-demand | Writes proper Obsidian syntax (wikilinks, callouts) |
| `obsidian-bases` | on-demand | Edits `.base` dashboard files |
| `defuddle` | when fetching URLs | Strips HTML crud before ingest |

All wiki skills use **MCP-first with filesystem fallback**: they prefer `mcp__obsidian-vault__*` tools, falling back to filesystem when MCP returns empty (e.g., for `.raw/` paths Obsidian's index ignores).

---

## Configuration files

- [`.obsidian/app.json`](.obsidian/app.json) — `userIgnoreFilters`, attachment folder, link defaults
- [`.obsidian/graph.json`](.obsidian/graph.json) — graph view filter to hide infra files
- [`CLAUDE.md`](CLAUDE.md) — rules Claude follows when working inside the vault
- [`docs/superpowers/specs/2026-04-20-claude-memory-vault-design.md`](docs/superpowers/specs/2026-04-20-claude-memory-vault-design.md) — full design rationale
- [`docs/NOTES.md`](docs/NOTES.md) — backlog, open items, what's been verified

---

## License

MIT. Attribution to:

- [Andrej Karpathy](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) — the LLM Wiki pattern
- [kepano/obsidian-skills](https://github.com/kepano/obsidian-skills) (MIT) — `obsidian-markdown`, `obsidian-bases`, `defuddle`
- [AgriciDaniel/claude-obsidian](https://github.com/AgriciDaniel/claude-obsidian) (MIT) — `save`, `wiki-ingest`, `wiki-query`, `wiki-lint` (adapted)
