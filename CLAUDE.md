# Vault rules

This is an Obsidian vault + second brain for Claude knowledge.

## Structure
- `.raw/` — raw sources; ingest promotes → wiki/
- `wiki/` — curated knowledge
- `_templates/` — start new pages from these
- `_attachments/` — images, PDFs

## Conventions
- Use Obsidian wikilinks `[[Note Name]]` for cross-references
- Every wiki page has frontmatter: title, created, updated, tags, mode
- New pages derive from matching `_templates/` file
- Update `wiki/index.md` when creating new pages
- Append to `wiki/log.md` on every ingest/save/lint
- Keep `wiki/hot.md` <= 500 words; overwrite on updates

## Don't
- Write directly to `.raw/` from a skill (input-only)
- Create pages outside the established folders without updating this CLAUDE.md
