# Project metadata and bootstrap

Read this reference only when `.agents/next-milestone.json` is absent, invalid, unsupported, path-unsafe, or the user explicitly asks to edit it. Metadata declares product direction; it never stores current scores, selected milestones, issue lists, or transient research.

## Version 1 contract

The only destination is the direct child `<git-root>/.agents/next-milestone.json`. The canonical key order is shown below. Lists preserve user-selected order.

```json
{
  "schema_version": 1,
  "project": {
    "id": "paper-trail",
    "name": "Paper Trail",
    "vision": "Help a reader trace a claim to the evidence that supports it.",
    "repository_identity": {
      "kind": "remote-url",
      "value": "https://example.com/acme/paper-trail"
    }
  },
  "comparators": [
    {
      "name": "Existing Research Product",
      "official_sources": [
        "https://example.com/products/research"
      ],
      "relevance": "It demonstrates an observable citation-review journey."
    }
  ],
  "evaluation_lenses": [
    {
      "name": "Evidence traceability",
      "question": "Can a reader move from a claim to its supporting source?"
    }
  ],
  "acceptance_journey": "A reader opens one report, follows one claim to its source, and returns to the report.",
  "non_goals": [],
  "ecosystem": {
    "related_repositories": []
  }
}
```

Required fields:

- `schema_version`: integer `1`.
- `project.id`: lowercase kebab-case, stable within the user's project-record namespace.
- `project.name`: non-empty display name.
- `project.vision`: one concise desired user or embedder outcome.
- `project.repository_identity`: `{"kind":"remote-url","value":"<canonical HTTPS URL>"}` or `{"kind":"module","value":"<canonical module identifier>"}`. Confirm it from a Git remote or repository-owned package/module metadata.
- `comparators`: 1–32 uniquely named real products. Each has 1–8 absolute credential-free HTTPS official seed URLs and a relevance statement.
- `evaluation_lenses`: 1–32 uniquely named questions tied to the vision.
- `acceptance_journey`: one bounded observable end-to-end outcome.

Optional content is still represented by required defaulted keys:

- `non_goals`: 0–64 explicit boundaries.
- `ecosystem.related_repositories`: 0–32 objects with lowercase-kebab `id`, literal `path_hint`, and `role`.

`path_hint` is an absolute literal path or starts with literal `${HOME}/`. It cannot contain dot segments, globs, other variables, control characters, or empty segments. Resolve it read-only, require a Git root, deduplicate canonical roots, and treat absence as evidence. Never create or clone a related repository.

The file is at most 65,536 bytes. Strings are trimmed, control-character-free, and at most 2,000 Unicode code points; IDs are at most 128, names at most 200, and URLs/path hints at most 2,048. Names and IDs are unique after Unicode NFKC, trimming, and case-folding. Unknown keys fail closed.

Canonical JSON uses the key order above, two-space indentation, unescaped UTF-8, and one trailing newline. The fingerprint is lowercase SHA-256 over those exact bytes.

## Repository identity

For `remote-url`, read the stored value with `git config --get remote.<name>.url` so global Git URL rewriting does not change the evidence, then normalize an HTTPS or SCP-style remote to absolute HTTPS: lowercase the hostname, remove credentials, query, fragment, default port, trailing slash, and terminal `.git`. Preserve the remaining path. For `module`, require a lowercase DNS host plus slash-separated ASCII path segments and no scheme, query, fragment, dot segments, globs, or trailing slash.

Repository identity must be verified before metadata is confirmed. Project records match only when both the exact `project.id` and canonical tagged identity match. Identity-free or ambiguous records may inform research but cannot block a candidate.

## Missing-file bootstrap

Before any repository measurement:

1. Resolve the Git root and verify `.agents` and the leaf are not symlinks. Explain that product metadata is required and confirmation will create one file.
2. Ask at most three short questions per interaction. Collect project name/ID, verifiable repository identity, and one-sentence vision; real comparators with official URLs and relevance; lenses, acceptance journey, optional non-goals, and optional related repositories. Use additional bounded rounds for incomplete answers. Never infer the vision or fabricate a URL.
3. Verify comparator publisher ownership from current official pages. HTTPS syntax alone does not establish official status.
4. Render the complete canonical JSON, exact destination, and SHA-256. Stop for explicit confirmation. Corrections produce a new preview and digest; silence or unrelated text is not confirmation.
5. Write the preview bytes to a temporary file, then run:

   ```text
   python3 <skill-dir>/scripts/write_project.py create <absolute-git-root> <preview-file> <sha256>
   ```

   The helper creates `.agents` safely when absent and uses exclusive, no-follow creation. It never overwrites a file that appeared after preview.
6. Run the validator, re-read the file, verify the displayed digest, and only then continue into research during the same invocation.

Decline creates nothing. A conflict validates the newly appeared file and shows the semantic difference; never replace it automatically. Bootstrap writes no other file in the consumer repository.

## Existing files and repairs

Run `python3 <skill-dir>/scripts/validate_project.py <absolute-git-root>`. Exit classes are:

| Code | Meaning | Action |
| --- | --- | --- |
| `0` | Valid canonical version 1 | Re-read and continue. |
| `2` | Absent | Run bootstrap. |
| `3` | Unsafe root/path/file | Report the exact path and stop. |
| `4` | Malformed, oversized, invalid UTF-8, or duplicate keys | Report parser-safe details and stop. |
| `5` | Unsupported version | Ask for a skill update or explicit migration; do not guess. |
| `6` | Invalid schema or canonical encoding | Report all safe field-specific repairs and stop. |
| `7` | Confirmed-write digest mismatch or destination conflict | Preserve the existing file, show the difference, and stop. |

The validator is read-only. It proves structural shape, bounds, URL syntax, canonical identity syntax, and credential absence. The agent separately verifies semantic quality: outcome-focused vision, official publisher ownership, lens relevance, and bounded journey.

For an explicit metadata edit, show a before/after semantic diff and old/new digests. Automated replacement is intentionally unsupported because a portable local file operation cannot compare-and-swap against a non-cooperating writer. After the user confirms and authorizes the ordinary file edit, validate and re-read it, then discard stale research and restart. Never silently rewrite invalid or unsupported metadata.
