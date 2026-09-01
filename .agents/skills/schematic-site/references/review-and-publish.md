# Review and publish gate

Read this reference whenever a site is considered ready for publication.

## Review contract

Use fresh subagents and give each the user's request, repository root, site directory, authoritative schematic/design sources, validation command, and the stance below. Reviewers inspect and return findings only; they do not edit files. Do not reveal another reviewer's findings, suspected bugs, or proposed fixes. A review is valid only if the reviewer actually inspected the relevant artifacts.

For every finding, require severity, affected file/location or component reference, concrete evidence, impact, and a bounded recommendation. `No findings` is valid. Retry an unusable or failed review once with a fresh agent; if the required review cannot be completed, do not publish.

### Stage 1: two independent reviews

Launch concurrently when possible:

1. **Circuit documentation and traceability reviewer** — tests coverage, reference/value/net consistency, provenance, component-purpose explanations, BOM links, uncertainty labels, and agreement with the authoritative design.
2. **Interaction, accessibility, and static-site reviewer** — tests navigation without JavaScript, keyboard and focus behavior, semantic HTML/SVG, responsive/zoom behavior, visual hierarchy, local-link integrity, portability, and deployment hygiene.

Evaluate every finding against the request and source evidence. Apply changes that improve accuracy, correctness, safety, accessibility, durability, or usability. Reject unsupported, duplicative, merely stylistic, or scope-expanding suggestions and record the reason briefly. Revalidate after edits.

### Stage 2: adversarial review

After Stage 1 fixes, launch a new reviewer. Ask it to try to disprove the site's readiness: find electrically misleading drawings, unsafe advice, incorrect calculations, mismatched identifiers, broken deep links, script-only behavior, stale source claims, false verification language, missing failure cases, and ways a reader could build the wrong thing.

Apply supported findings with the same disposition standard, then revalidate.

### Stage 3: accuracy and correctness reviews

After adversarial fixes, launch two fresh reviewers concurrently when possible:

1. **Accuracy reviewer** — independently traces every material electrical and quantitative claim to design files, calculations, simulation/measurement evidence, inventory records, and primary sources. Recalculate representative values and inspect risky corners.
2. **Correctness reviewer** — independently exercises the finished artifact: all pages/assets/anchors, every clickable component destination, keyboard behavior, browser history, narrow and wide layouts, reduced motion, and the validation/publish commands. It also checks that the packaged directory is exactly what will be uploaded.

Before these final two reviews, generate a manifest and content digest with `validate_site.py --manifest <file> --digest-file <file>` and give both reviewers that digest. Apply supported findings and rerun all validation. If content changes, the reviewed digest is stale: regenerate it and rerun whichever final review stance covers the changed area. Do not substitute one reviewer for both stances.

After both final reviews cover the unchanged digest, create a review receipt outside the publish directory:

```json
{
  "schema_version": "schematic-site-review-v1",
  "payload_sha256": "<64 lowercase hex characters>",
  "reviews": {
    "independent": [
      {"reviewer": "<distinct reviewer id>", "status": "complete"},
      {"reviewer": "<distinct reviewer id>", "status": "complete"}
    ],
    "adversarial": {"reviewer": "<distinct reviewer id>", "status": "complete"},
    "accuracy": {"reviewer": "<distinct reviewer id>", "status": "complete"},
    "correctness": {"reviewer": "<distinct reviewer id>", "status": "complete"}
  }
}
```

The five reviewer identifiers must be distinct. This receipt is operational evidence, not a cryptographic identity attestation. The publisher snapshots the manifest, recomputes its content digest, and refuses a stale or incomplete receipt.

## Publication

Target SSH endpoint: `infra-admin@100.82.43.93`, which serves `insecure.birb.homes`. The remote document root is intentionally not guessed. Obtain the dedicated hosting root from authoritative deployment configuration and choose a simple site slug. The publisher permits dedicated roots only beneath `/srv`, `/var/www`, `/home/infra-admin/www`, or `/opt/insecure-sites`; update the script deliberately if authoritative configuration uses another safe prefix. The web server must serve `<remote-root>/<site-slug>/current`.

Before publishing:

1. Confirm explicit user authorization for this upload and exact destination.
2. Confirm all required review stages completed against the final content.
3. Run local validation and serve/test the exact directory to upload.
4. Run a dry-run:

   ```bash
   <skill-dir>/scripts/publish_site.sh \
     --source <site-dir> \
     --review-receipt <receipt.json> \
     --remote-root <absolute-dedicated-hosting-root> \
     --site-slug <site-slug>
   ```

5. Inspect the resolved source, immutable temporary snapshot, content digest, exact manifest, host, managed directory, versioned release directory, and `current` link. The validator rejects hidden files, symlinks, unexpected file types, unreferenced files, and likely secret assignments; only manifest entries are transferred.
6. Apply only after the dry-run is clean:

   ```bash
   <skill-dir>/scripts/publish_site.sh \
     --source <site-dir> \
     --review-receipt <receipt.json> \
     --remote-root <absolute-dedicated-hosting-root> \
     --site-slug <site-slug> \
     --apply
   ```

7. The script uploads into a new release directory and atomically replaces the managed `current` symlink only after transfer. It retains older versioned releases for rollback and does not perform cleanup.
8. Open the final public URL and smoke-test several component deep links. Report the URL and verification result.

Stop rather than guessing if host identity, remote path, web-root mapping, authentication, or publication authorization is unclear. Never upload source secrets, simulation caches, repository metadata, review notes, or files outside the validated site directory.
