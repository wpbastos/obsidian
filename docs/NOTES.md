# NOTES — Future Work & Open Items

Running list of deferred items, known bugs, and tuning opportunities for the Obsidian Claude Memory Vault. Not part of the design spec — this is the working backlog.

---

## Open Bugs

(none active — see "Recent Fixes" below for items resolved or awaiting re-verification)

---

## Recent Fixes (Awaiting Re-Verification)

### fswatch auto-ingest: MCP reads `.raw/` as empty
**Original symptom**: `claude -p` invoked by the watcher reported "The source file is empty (0 bytes)" even when the file had real content.
**Root cause**: `.raw/` is in `userIgnoreFilters`. The Obsidian REST API refuses to read ignored paths and returns empty when called via `obsidian_get_file_contents`.
**Fix applied**: rewrote the "Tool Preference" section in all 4 wiki skills (`save`, `wiki-ingest`, `wiki-query`, `wiki-lint`) from "use filesystem for `.raw/`" → "MCP-first with filesystem fallback". Now the skill is instructed to retry with the filesystem `Read` tool whenever an MCP call returns empty/null/404 where content is expected. This generalizes beyond `.raw/` and covers any future ignored-path issues.
**Re-verification needed**: drop a fresh file in `.raw/`; confirm wiki pages get created and `wiki/log.md` updates. Until that happens, end-to-end auto-ingest is **fix-applied-but-unverified**.

---

## Deferred Features

### Canvas skill
**Why deferred**: Needs real usage on ≥30 pages to know if visual maps add value. Can clone from AgriciDaniel/claude-obsidian repo.

### Autoresearch skill
**Why deferred**: Risk of runaway loops; revisit after v1 stabilizes. Autonomous research loop: search → fetch → synthesize → file.

### Lint cron (Layer 3)
**Why deferred**: Self-nudging (Layer 2) via ops counter is the primary mechanism. Cron only if nudges get ignored for weeks.
**Activation**: use `CronCreate` tool with a weekly `/wiki-lint` schedule.

### Dataview fallback dashboard
**Why skipped (not deferred)**: Bases is native and covers the use case. Remove this item if confidence in Bases is ever shaken.

---

## Tuning Opportunities

### Ops-since-lint threshold (currently 15)
Track whether nudges come too early or too late after a month of real use. Adjust in `save/SKILL.md`, `wiki-ingest/SKILL.md`, `wiki-lint/SKILL.md`.

### Watcher debounce window (currently 10s)
fswatch `-l 10` bundles events. Increase to 30s if many small drops fire too many claude invocations; decrease if ingest feels sluggish.

### Watcher file extensions (currently `.md/.pdf/.txt/.html`)
Add `.docx`, `.rtf` if you start dropping those. Watcher globs in `~/bin/obsidian-raw-watcher.sh`.

---

## Infrastructure

### Git version control on the vault
**Why deferred**: Add once the capture pipeline is proven green end-to-end.
**When**: after the MCP-reads-empty bug above is fixed and ingest completes cleanly.
**What to include in `.gitignore`**:
- `.obsidian/workspace.json` (session-specific)
- `.obsidian/workspace-mobile.json`
- `.obsidian/plugins/*/data.json` (plugin caches)
- `.raw/` (source dumps — rebuilt from external sources)
- `.scratch/`

### Package all skills as a Claude Code plugin
**Why deferred**: skills currently installed individually under `~/.claude/skills/`. Works fine on this machine but isn't portable. A plugin packages everything so it's installable elsewhere with `/plugin install`.

**Scope**:
- 7 skills: `save`, `wiki-ingest`, `wiki-query`, `wiki-lint`, `obsidian-markdown`, `obsidian-bases`, `defuddle`
- Optional bundling: vault scaffold template, fswatch + LaunchAgent setup script, user CLAUDE.md pointer snippet

**Structure**:
```
obsidian-vault-plugin/
├── .claude-plugin/plugin.json   ← manifest
├── skills/
│   ├── save/SKILL.md
│   ├── wiki-ingest/SKILL.md
│   ├── wiki-query/SKILL.md
│   ├── wiki-lint/SKILL.md
│   ├── obsidian-markdown/{SKILL.md, references/}
│   ├── obsidian-bases/{SKILL.md, references/}
│   └── defuddle/SKILL.md
├── scripts/                     ← optional helpers
│   ├── install-watcher.sh       ← sets up fswatch + LaunchAgent
│   ├── scaffold-vault.sh        ← creates folders, stubs, templates
│   └── append-user-claude-md.sh ← adds vault pointer to ~/.claude/CLAUDE.md
└── README.md                    ← install + setup instructions
```

**When**: after end-to-end ingest is verified working.

**Considerations**:
- License (MIT, attribution to kepano + AgriciDaniel)
- Update mechanism — version field in plugin.json
- Make vault path configurable (currently hardcoded `~/Projects/_obsidian/`); accept env var or prompt at install
- Local install: `/plugin install ./obsidian-vault-plugin` for testing
- Marketplace: optional public distribution via plugin marketplace

---

### Backup strategy
**Options**:
- iCloud Drive sync of the vault folder
- Git remote (GitHub private repo)
- Time Machine
**Pick one** once git is in place.

---

## Known Unknowns (won't know until tested)

- Whether `mcp__obsidian-vault__*` wildcard actually grants all MCP tools or silently fails for some — first real wiki-ingest success will confirm
- Whether headless `claude -p` from LaunchAgent loads skills consistently across reboots — long-term observation
- Whether Obsidian Bases file format stays stable across Obsidian versions — re-test after each Obsidian update

---

## Verified Working

Keep this section honest — move items here only after real observation.

### Skills + setup
- [x] 7 skills discovered at session start (confirmed via system-reminder skill list)
- [x] All 7 skills pass structural audit (frontmatter valid, body under 500 lines, no dead refs, all supporting files exist)
- [x] `~/.claude/CLAUDE.md` vault pointer appended idempotently (sentinel-guarded)
- [x] `autoMemoryEnabled: false` merged into `~/.claude/settings.json` without data loss
- [x] Templater template folder set to `_templates/`

### Watcher pipeline
- [x] fswatch detects file events in `.raw/` (confirmed via watcher log `eligible files` line)
- [x] LaunchAgent persists across logout/reboot (KeepAlive)
- [x] Bash-glob detection robust to preserved-mtime files (drag-drop, mv, downloads)
- [x] Lockfile prevents concurrent claude invocations
- [x] `claude -p` launches from LaunchAgent with user auth working
- [x] `claude -p --permission-mode bypassPermissions` passes permission walls and runs wiki-ingest skill

### Obsidian configuration
- [x] `userIgnoreFilters` working with plain-substring format (NOT anchored regex)
- [x] Hidden from graph/search/explorer: `.raw/`, `.scratch/`, `docs/`, `_templates/`, `_attachments/`, `CLAUDE.md`, `.base`
- [x] Graph view filter (`graph.json` `search`) hides `meta/` and `CLAUDE.md` reliably
- [x] Vault `CLAUDE.md` doesn't generate phantom `[[like-this]]` node (fixed by code-quoting the example)
- [x] `dashboard.base` exists at `wiki/meta/`, parseable, hidden from graph

### End-to-end pipelines
- [x] **wiki-ingest** end-to-end (auto-ingest of `building_prod_ai_agent_2026_microsoft_stack.md` produced 19 wiki pages: 1 source, 7 entities, 9 concepts, 1 architecture, 1 comparison)
- [x] **wiki-query** end-to-end ("what do you know about FastAPI?" → answer synthesized from `hot.md` + entity page with proper `[[wikilink]]` citations)
- [x] **MCP-first with filesystem fallback** rule operational (verified live: MCP returned connection refused → filesystem `Read` succeeded → answer produced — exactly the designed behavior)
- [x] `mcp__obsidian-vault__*` wildcard grants tool access (MCP calls fired without "tool not allowed" errors)

### Still pending verification
- [ ] **`/save`** end-to-end — file a conversation as a wiki note, confirm new page in `wiki/<folder>/`, `index.md` and `log.md` updated
- [ ] **`/wiki-lint`** end-to-end — full pass finds orphans/dead links, refreshes `hot.md`, resets ops counter
- [ ] **`update hot cache`** narrow path — rewrite `hot.md` from scratch
- [ ] **Layer 2 nudge** — the "Wiki lint overdue (N ops since last lint)" message after 15 saves/ingests (currently at 1 ingest)
- [ ] **`defuddle` + URL ingest** — `ingest this URL: https://...` → defuddle strips HTML → wiki pages produced
- [ ] **`obsidian-bases` on edit** — modify `wiki/meta/dashboard.base` via the skill
- [ ] **Cross-project access** — open Claude Code in a *different* project, run `what do you know about FastAPI?` and confirm the vault pointer in `~/.claude/CLAUDE.md` triggers the same answer (this is the whole "shared knowledge" thesis — currently unconfirmed)
- [ ] **Watcher resilience across reboot** — log out, log back in, drop a file, confirm LaunchAgent restarted itself and ingest still works

---

## Source Documents

- Spec: [`docs/superpowers/specs/2026-04-20-claude-memory-vault-design.md`](superpowers/specs/2026-04-20-claude-memory-vault-design.md)
- Watcher script: `~/bin/obsidian-raw-watcher.sh`
- LaunchAgent: `~/Library/LaunchAgents/com.obsidian-vault.raw-watcher.plist`
- Watcher log: `~/Library/Logs/obsidian-raw-watcher.log`
- Skills: `~/.claude/skills/{save,wiki-ingest,wiki-query,wiki-lint,obsidian-markdown,obsidian-bases,defuddle}/`
