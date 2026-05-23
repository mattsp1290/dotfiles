---
name: polish-blog
description: Apply copyeditor patterns to a rewritten blog post to bring it closer to publish-ready. Run after /rewrite-blog.
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep
---

# Polish Blog Post

Run a copyeditor pass over a blog post that's already been through `/rewrite-blog`. The rewrite captures Matt's voice; this pass applies the patterns an actual copyeditor applied when landing the last several posts in Confluence.

This skill does *not* re-do the voice rewrite. It tightens mechanics, swaps a handful of AI-tell words the rewrite sometimes leaves behind, flattens dangling constructions, and trims the more indulgent Matt-voice flourishes (personal anecdote openers, fragment-punch riffs, first-person color asides) that the published versions consistently have had removed.

## Usage

- `/polish-blog path/to/draft-rewritten.md`
- `/polish-blog` — then paste the draft text

## Input

Accept one of:
1. **A file path** passed as an argument — read the file.
2. **Pasted text** in the user's message — use it directly.
3. **Neither** — ask the user to paste a draft or provide a file path.

## Steps

1. Read the input draft.
2. Read `${CLAUDE_SKILL_DIR}/PATTERNS.md` for the full pattern catalog with before/after examples.
3. Apply the pattern categories in order:
   - Mechanics and punctuation
   - Vocabulary swaps
   - Active / direct rewrites
   - Voice-trim patterns
   - Clarifying tails
4. Run the self-check below against the output.
5. Output the polished draft directly in the conversation. If the input was a file path, offer to write a `-polished.md` sibling file (e.g., `TOTW-AI-7-rewritten.md` → `TOTW-AI-7-polished.md`).

## Self-check before finalizing

- No em-dash parentheticals remain in narrative prose (lists and code blocks are fine).
- No AI-tell vocabulary clusters ("valuable", "critically", "leverage", "utilize").
- No setup phrases like "The rule of thumb:", "The thing that makes this practical is", "The key design decision is".
- No first-person anecdote openers at the top of the article.
- No "I've been there" / "I don't use them yet" / "I could see every large repo..." color asides mid-article.
- Fragment-punch riffs in narrative prose have been smoothed into one flowing sentence. Fragments that close a section or land a list are fine.
- Code blocks, JSON snippets, tables, headings, link URLs, and the footer `Sources:` list are byte-identical to the input.
- Contractions from the rewrite are preserved — the editor doesn't un-contract.

## What this skill won't do

- Change code samples, frontmatter, YAML, JSON, or tables.
- Undo `/rewrite-blog`'s contractions or casual voice in lists and section closers.
- Rewrite section headings or restructure the article.
- Touch the `Sources:` list at the bottom.

If the draft needs restructuring or a heavier voice pass, route back to `/rewrite-blog` or do it by hand — `/polish-blog` is strictly a copyedit pass.
