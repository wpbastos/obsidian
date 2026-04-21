# Claude Memory Vault — Design Spec

**Date**: 2026-04-20
**Status**: Approved
**Scope**: Obsidian vault as shared second brain for Claude Code across all projects

---

## Goal

Build an Obsidian vault at `~/Projects/_obsidian/` that serves as a shared second brain across every Claude Code project. Knowledge is explicitly captured (no auto-memory), curated into a wiki, and readable by Claude from any project.

---

## Non-Goals (v1)

- Visual canvas boards
- Autonomous research loops
- Dataview fallback dashboard

---

## Modes

Combined: D (Personal) + B (GitHub/Codebase) + E (Research)

---

## Vault Layout

```
~/Projects/_obsidian/
├── .raw/                       ← hand-dropped sources (articles, PDFs, URLs)
├── wiki/
│   ├── index.md                ← catalog: every page + 1-line summary
│   ├── hot.md                  ← always-loaded context (~500 words)
│   ├── log.md                  ← append-only: ingests, saves, lints
│   ├── overview.md             ← executive summary
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
├── _templates/                 ← Templater templates per note type
├── _attachments/               ← images, PDFs
├── CLAUDE.md                   ← vault-scoped rules
├── .obsidian/snippets/vault-colors.css
└── docs/superpowers/specs/     ← this spec
```

---

## Skills

7 skills, all user-scoped. Installed at `~/.claude/skills/<skill-name>/SKILL.md` (Claude Code's auto-discovery path for user-level skills).

| # | Skill | Trigger | What it does |
|---|---|---|---|
| 1 | obsidian-markdown | on-demand | Writes proper Obsidian syntax (wikilinks, embeds, callouts, frontmatter) |
| 2 | obsidian-bases | on-demand | Edits `.base` files for native dashboards |
| 3 | defuddle | when fetching web sources | Strips HTML crud before ingest |
| 4 | save | `/save`, `/save [name]` | Files current conversation as a wiki note; updates index/log/hot |
| 5 | wiki-ingest | `ingest [file]`, `ingest all of these` | Reads `.raw/`, classifies + routes; updates index/log/hot |
| 6 | wiki-query | `what do you know about X?` | Reads hot → index → pages, synthesizes with citations |
| 7 | wiki-lint | `/wiki-lint`, `lint the wiki`, `update hot cache` | Finds orphans, dead links, stale claims, oversized files; rewrites hot.md |

---

## Lint Triggering

Lint is layered to balance automation against user control.

### Layer 1 — Always-On, Light

`save` and `wiki-ingest` append 1-line summaries to `hot.md` (truncate if >500 words) and append to `log.md`. No trigger needed.

### Layer 2 — Self-Nudging (Recommended Default)

`log.md` keeps a counter `<!-- ops_since_lint: N -->`. `save` and `wiki-ingest` increment it. When N >= 15, they print:

```
Wiki lint overdue (N ops since last lint). Run /wiki-lint when convenient.
```

`/wiki-lint` resets the counter to 0.

### Layer 3 — Scheduled (Optional, Deferred)

Scheduled weekly via `CronCreate` if nudges are persistently ignored.

---

## Settings

Auto-memory disabled at user scope. Add to `~/.claude/settings.json`:

```json
{"autoMemoryEnabled": false}
```

---

## Cross-Project Access

Append the following block to `~/.claude/CLAUDE.md`:

```markdown
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
```

---

## MCP Integration

`mcp-obsidian` (via `uvx`) is already installed at user scope. Skills use MCP tools for vault I/O where they add value:

- `obsidian_get_file_contents`
- `obsidian_patch_content`
- `obsidian_simple_search`
- `obsidian_append_content`
- `obsidian_batch_get_file_contents`
- `obsidian_complex_search`

Direct filesystem reads/writes are used where MCP adds no value.

---

## Vault CLAUDE.md

Rules applied when Claude works inside the vault:

```markdown
# Vault rules

This is an Obsidian vault + second brain for Claude knowledge.

## Structure
- `.raw/` — raw sources; ingest promotes → wiki/
- `wiki/` — curated knowledge
- `_templates/` — start new pages from these
- `_attachments/` — images, PDFs

## Conventions
- Use Obsidian wikilinks [[like-this]] for cross-references
- Every wiki page has frontmatter: title, created, updated, tags, mode
- New pages derive from matching `_templates/` file
- Update `wiki/index.md` when creating new pages
- Append to `wiki/log.md` on every ingest/save/lint
- Keep `wiki/hot.md` <= 500 words; overwrite on updates

## Don't
- Write directly to `.raw/` from a skill (input-only)
- Create pages outside the established folders without updating this CLAUDE.md
```

---

## Workflows

### Capture (`/save`)

1. Classify the current conversation (concept, entity, source, project, etc.)
2. Pick the matching template from `_templates/`
3. Generate slug from title
4. Write `wiki/<folder>/<slug>.md` with full frontmatter
5. Append 1-line entry to `wiki/index.md`
6. Append timestamped entry to `wiki/log.md` and increment ops counter
7. Prepend summary to `wiki/hot.md`; truncate to 500 words if needed

### Ingest (`ingest [file]` or `ingest all of these`)

1. Read target file(s) from `.raw/`
2. If URL or HTML source: run `defuddle` to strip markup
3. Classify content type; extract 8-15 key ideas as candidate pages
4. Write pages via `obsidian-markdown` into the appropriate `wiki/` subfolder
5. Cross-reference existing pages with wikilinks
6. Update `wiki/index.md`, `wiki/log.md`, `wiki/hot.md`

### Query (`what do you know about X?`)

1. Read `wiki/hot.md` — recent context, always loaded
2. If insufficient: read `wiki/index.md` to locate relevant pages
3. Drill into specific pages by subfolder
4. Synthesize an answer with `[[wikilink]]` citations to source pages

### Lint (`/wiki-lint`)

1. Scan all `wiki/` pages for orphans (no inbound links)
2. Check for dead wikilinks (targets that do not exist)
3. Flag pages with `updated` dates older than 90 days containing factual claims
4. Flag pages exceeding a size threshold (suggest splitting)
5. Rewrite `wiki/hot.md` from scratch based on current high-signal pages
6. Reset `<!-- ops_since_lint: N -->` counter to 0 in `log.md`

---

## Bootstrap — Implementation Deliverables

The following must be created to make the vault operational:

| # | Deliverable | Path |
|---|---|---|
| 1 | All vault folders | See layout above |
| 2 | 9 Templater templates | `_templates/` (concept, entity, source, journal, project, architecture, paper, question, comparison) |
| 3 | Stub files | `wiki/index.md`, `wiki/hot.md`, `wiki/log.md`, `wiki/overview.md` |
| 4 | Bases dashboard | `wiki/meta/dashboard.base` |
| 5 | CSS snippet | `.obsidian/snippets/vault-colors.css` |
| 6 | Vault rules | `CLAUDE.md` at vault root |
| 7 | Global pointer | Append vault block to `~/.claude/CLAUDE.md` |
| 8 | Settings | Add `"autoMemoryEnabled": false` to `~/.claude/settings.json` |
| 9 | Skills | Install 7 skills at `~/.claude/skills/<skill-name>/SKILL.md` |
| 10 | Cleanup | Delete `Welcome.md` if present |

---

## Template Schemas

Each Templater template includes a YAML frontmatter block. Minimum required fields:

```yaml
---
title: "{{title}}"
created: {{date}}
updated: {{date}}
tags: []
mode: D | B | E
---
```

Template-specific additions:

| Template | Extra frontmatter fields |
|---|---|
| concept | `related: []`, `status: draft\|stable` |
| entity | `type: person\|tool\|library`, `url:` |
| source | `source_url:`, `author:`, `published:` |
| journal | `mood:` (optional) |
| project | `repo:`, `status: active\|paused\|archived` |
| architecture | `repo:`, `layer: frontend\|backend\|infra\|data` |
| paper | `doi:`, `authors: []`, `venue:` |
| question | `status: open\|answered`, `answer_ref:` |
| comparison | `subjects: []` |

---

## Open Questions / Deferred

| Item | Status | Decision |
|---|---|---|
| Canvas skill | Deferred to v2 | Needs real usage to determine value |
| Autoresearch skill | Deferred to v2 | Risk of runaway loops; revisit after v1 stabilizes |
| Dataview fallback dashboard | Skipped | Bases is native; Dataview not needed |
| Lint cron (Layer 3) | Deferred | Add only if nudges are consistently ignored |
| Ops-since-lint threshold (currently 15) | Tune after 1 month | Adjust based on actual capture cadence |

---

## Attribution / Sources

- Design inspired by Karpathy's LLM Wiki pattern (Gist: `karpathy/442a6bf555914893e9891c11519de94f`)
- Utility skills (`obsidian-markdown`, `obsidian-bases`, `defuddle`) sourced from `kepano/obsidian-skills` (MIT)
- Wiki skills (`save`, `wiki-ingest`, `wiki-query`, `wiki-lint`) adapted from `AgriciDaniel/claude-obsidian` (MIT)

---

## Post-Implementation Addendum

Locked in during and after the initial bootstrap, beyond the original design:

### Obsidian configuration (`.obsidian/app.json`)
- `attachmentFolderPath: "_attachments"`
- `newFileLocation: "folder"` / `newFileFolderPath: "wiki"`
- `alwaysUpdateLinks: true`, `useMarkdownLinks: false`, `newLinkFormat: "shortest"`
- `userIgnoreFilters`: `.raw/`, `.scratch/`, `docs/`, `_templates/` — hidden from search, graph, and file explorer

### MCP-first tool preference (all 4 wiki skills)

Each of `save`, `wiki-ingest`, `wiki-query`, `wiki-lint` now has:

- A **Tool Preference: MCP-First** section near the top instructing Claude to prefer `mcp__obsidian-vault__*` for vault I/O and fall back to filesystem (Read/Write/Edit/Glob/Grep) only for `.raw/`, `.gitkeep`, or paths outside the vault.
- `allowed-tools` frontmatter expanded with `mcp__obsidian-vault__*` wildcard (per Claude Code's MCP permission syntax — matches all tools from that MCP server without listing each).

The vault is reached via the already-configured user-scope `mcp-obsidian` MCP server, which uses Obsidian's Local REST API plugin.

### Auto-ingest on file drop (fswatch + launchd)

Reactive auto-ingest for `.raw/`, in place of polling:

| Component | Path |
|---|---|
| Watcher script | `~/bin/obsidian-raw-watcher.sh` |
| LaunchAgent | `~/Library/LaunchAgents/com.obsidian-vault.raw-watcher.plist` |
| Log | `~/Library/Logs/obsidian-raw-watcher.log` |
| Dependency | `fswatch` (Homebrew) |

Behavior: on any `.md`/`.pdf`/`.txt`/`.html` file created in `.raw/`, the watcher debounces 10 seconds, then invokes `claude -p "Run wiki-ingest on these new files: <paths>"` headlessly. Survives logout/reboot via launchd.

Management:
- Stop: `launchctl unload ~/Library/LaunchAgents/com.obsidian-vault.raw-watcher.plist`
- Start: `launchctl load ~/Library/LaunchAgents/com.obsidian-vault.raw-watcher.plist`

### Templater plugin
Required for `<% tp.file.title %>` and `<% tp.date.now() %>` interpolation in `_templates/`. Already installed and configured (template folder → `_templates/`).

### Deferred (still)
- Git version control on the vault — add after the capture pipeline is proven working.
