# AGENTS.md

## Project Overview

Astro documentation site for SystemVerilog / UVM / SoC verification learning. Chinese language content.

## Quick Commands

```bash
npm install          # first time setup
npm run dev          # local dev server at http://localhost:4321/VerificationGuide
npm run build        # build + pagefind search index
```

## Content Structure

- `docs/guides/` — Markdown learning guides (SV, UVM, SoC). These are the primary content.
- `docs/examples/` — SystemVerilog example files (.sv)
- `src/` — Astro components, layouts, pages (minimal customization)

## Key Conventions

- All guide content is in **Chinese**
- Frontmatter in guides includes: `title`, `description`, `pubDate`, `category`, `order`, `tags`
- Code blocks: use `verilog` language tag, Shiki highlights with `github-light`/`github-dark` themes
- File naming pattern for guides: `sv-通用语法.md`, `uvm-知识详解.md` (category prefix + Chinese name)
- Math support enabled via `remark-math` + `rehype-katex` (use `$...$` for inline, `$$...$$` for block)

## Deployment

GitHub Pages at `https://caomaolufei.github.io`. Build output goes to `dist/` (gitignored).

## Gotchas

- `pagefind` runs post-build for search indexing — if search is broken, rebuild with `npm run build`
- Verilog syntax highlighting is explicitly configured in `astro.config.mjs` — don't remove the `langs: ['verilog']` config
