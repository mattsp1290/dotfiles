# Copyeditor Patterns — `/polish-blog` reference

These patterns were derived from comparing three `-rewritten.md` drafts (output of `/rewrite-blog`) against the versions that landed on Confluence after a copyeditor pass: TOTW-AI-3 → TOTW-AI-4 Rules, TOTW-AI-5 Skills, TOTW-AI-6 Hooks.

Apply the categories in order. Each rule has at least one real before/after drawn from those diffs.

---

## 1. Mechanics and punctuation

### Break em-dash compound sentences

Em-dashes that glue two independent clauses together get swapped for a period. In narrative prose, prefer two short sentences.

- Before: `CLAUDE.md has a scaling problem: as your project grows, the file gets longer, instructions get buried, and rules that only apply to part of the codebase load into every conversation.`
- After: `CLAUDE.md has a scaling problem. As your project grows, the file gets longer, instructions get buried, and rules that only apply to part of the codebase load into every conversation whether they're relevant or not.`

- Before: `The simplest approach—one file per concern:`
- After: `The simplest approach. One file per concern:`

- Before: `load on demand—only when Claude reads files matching the specified patterns`
- After: `only load when Claude reads files matching the specified patterns`

Em-dashes inside a single clause as a mid-sentence aside are usually fine. The test: can you replace `—` with `.` without breaking the grammar? If yes, do it.

### Em-dash to comma (when the aside is short)

- Before: `covered CLAUDE.md—the persistent context Claude reads every session`
- After: `covered CLAUDE.md, the persistent context Claude reads every session`

### Remove bold on leading phrases

If a sentence opens with `**Bold phrase**` and the bold is just the topic of the sentence, drop the bold. Keep bold only when it's visually flagging a parallel structure across multiple items.

- Before: `**Rules without `paths` frontmatter** load at session start, just like CLAUDE.md.`
- After: `Rules without `paths` frontmatter load at session start, just like CLAUDE.md.`

### Colon-after-short-phrase → period

When a short setup phrase is followed by a colon and then a full sentence, prefer a period.

- Before: `The simplest approach—one file per concern:`
- After: `The simplest approach. One file per concern:`

---

## 2. Vocabulary swaps

Direct word substitutions the editor made repeatedly. These are not blanket find-and-replace — check the surrounding context — but the direction is consistent.

| Before | After |
|---|---|
| valuable | useful |
| critically | (delete) |
| polluting | bloating |
| hold (supporting files) | contain |
| instructions (casual context) | stuff |
| The thing that makes this practical is | The real power is |
| The rule of thumb: | (delete — start directly) |
| I like | (often replaced with attribution, e.g., "the community shorthand") |

### Evidence

- Before: `Rules are especially valuable in monorepos.`
- After: `Rules are especially useful in monorepos.`

- Before: `and—critically—scope them to specific file patterns`
- After: `and scope them to specific file patterns so they only load when they actually matter`

- Before: `without polluting the root CLAUDE.md`
- After: `without bloating the root CLAUDE.md`

- Before: `The rule of thumb: if you find yourself writing "when working on X files, do Y"...`
- After: `If you find yourself writing "when working on X files, do Y"...`

- Before: `That directory can hold supporting files`
- After: `That directory can contain supporting files`

---

## 3. Active and direct rewrites

### Passive or dangling participle → active causal

- Before: `User-level rules load before project rules, giving project rules higher priority when they conflict.`
- After: `User-level rules load before project rules, so project rules take priority when they conflict.`

- Before: `Each rule file is loaded into the context window.`
- After: `Each rule file loads into the context window.`

### "They let you X" → "You X"

When the subject is clearly implied, drop the intermediate clause.

- Before: `Rules solve this. They let you split instructions into focused files...`
- After: `Rules fix this. You split instructions into focused files...`

### Descriptive verb over imperative

When instructing the reader about an option, the editor softened imperatives into descriptive phrasing.

- Before: `If you maintain rules that apply across multiple repos, use symlinks:`
- After: `If you maintain rules that apply across multiple repos, symlinks work:`

---

## 4. Voice-trim patterns (the big one)

This is where the editor pulled back hardest, especially in TOTW-AI-6. `/rewrite-blog` leans into personal anecdote, fragment-punch riffs, and first-person asides. The published versions consistently trim them.

### Cut personal anecdote openers

The cold-open "I spent a solid week..." paragraph was removed entirely. The article starts with the technical framing instead. **Keep the technical framing, drop the personal opener.**

- Before (TOTW-AI-6 rewritten opener):
  > I spent a solid week with a Rule in my CLAUDE.md that said "never merge PRs." Claude ignored it twice. Not maliciously, it just got buried under 400 lines of other context and the model decided `gh pr merge` was a reasonable next step. That's when I stopped trying to solve enforcement problems with instructions and started solving them with code.
  >
  > [TOTW-AI-5](...) covered Skills, the active procedures Claude runs when you invoke them. Skills are great, but they wait for you...
- After (published):
  > [TOTW-AI-5](...) covered Skills — reusable procedures Claude runs on demand. Skills are powerful, but they require someone to type `/review` or `/deploy`. Nothing happens until you invoke them.

### Cut first-person color asides

Mid-article "I've been there" / "I don't use them yet" / "I could see every large repo having one of these eventually" asides were removed wholesale.

- Before: `Most people never need `prompt` or `agent` hooks. I don't use them yet. Start with `command`...`
- After: `Most people never need `prompt` or `agent` hooks. Start with `command`...`

- Before: `Adding a new antipattern means adding one checker function to the registry. The hook infrastructure stays the same. I could see every large repo having one of these eventually.`
- After: `Adding a new antipattern means adding one checker function to the registry. The hook infrastructure stays the same.`

- Before: `If the rule has gray area, you'll spend more time fighting false positives than you save. I've been there.`
- After: `If the rule has gray area, you'll spend more time fighting false positives than you save.`

### Smooth fragment-punch riffs in narrative prose

Fragment-punches that elaborate on a point that was already clear get merged back into one flowing sentence. The rhythm that's fun in a blog post is what the editor strips out.

- Before: `Simple rule. Absolute. No gray area. The deny reason tells Claude exactly what to do instead. That last part matters more than people think.`
- After: `This is the quintessential blocking hook. The rule is simple, absolute, and the deny reason tells Claude exactly what to do differently (have a human merge it).`

- Before: `Code. With exit codes and everything.`
- After: (cut entirely — the preceding sentence already makes the point)

**Exceptions — keep fragment-punches when:**
- They're the last sentence of a section (they land the section).
- They're inside a bulleted list item.
- They're paired with a definition or callout ("Pure observer. Logs what happened without affecting anything.").

### Cut elaborative tails that restate the point

- Before: `CLAUDE.md is static. This isn't.`
- After: (cut — the preceding paragraph already said CLAUDE.md can't provide this)

- Before: `Pretty useful for keeping hooks targeted instead of firing on every single Bash command.`
- After: (cut — the `if` example already shows this)

---

## 5. Clarifying tails

Sometimes the editor *added* a short clarifying phrase at the end of a sentence where the rewrite left the reason implicit. Use sparingly — only when the sentence would benefit from spelling out "why it matters."

- Before: `...rules that only apply to part of the codebase load into every conversation.`
- After: `...rules that only apply to part of the codebase load into every conversation whether they're relevant or not.`

- Before: `This rule only loads into Claude's context when it reads a file matching `src/api/**/*.ts`. When Claude is working on frontend code, it never sees these instructions—keeping context focused and reducing the chance of instruction overload.`
- After: `This rule only loads into Claude's context when it reads a file matching `src/api/**/*.ts`. When Claude is working on frontend code, it never sees these instructions. Less noise, less context wasted, less chance of instruction overload.`

---

## 6. What NOT to touch

- **Code blocks** (triple-backtick or fenced): byte-identical.
- **JSON, YAML, Bash snippets inside code blocks:** byte-identical.
- **Frontmatter examples:** byte-identical, even when they contain `paths:` or `description:` strings that look like prose.
- **Tables:** byte-identical (columns, pipes, header rows).
- **Headings:** keep the heading level and text as-is.
- **Link URLs:** byte-identical. Link text may be lightly edited if the surrounding prose demands it.
- **Footer `Sources:` list:** byte-identical.
- **Contractions** from the rewrite ("don't", "can't", "you've") — the editor doesn't expand them.
- **Section structure:** don't reorder sections, don't merge sections, don't split sections.

---

## Running self-check

After applying all pattern categories, scan the output once more for:

1. Any remaining em-dash compound sentences in narrative prose.
2. Any remaining vocabulary in the swap table (category 2) that was missed.
3. Any dangling `-ing` clause at the end of a sentence that doesn't earn its keep.
4. Any first-person color aside that doesn't tell the reader something they need.
5. Any fragment-punch sequence of three or more in a row in narrative prose.

If the draft is significantly shorter than the input, that's expected — the voice trim and elaborative-tail cuts consistently remove 5–10% of the word count. If it's *longer*, something has gone wrong.
