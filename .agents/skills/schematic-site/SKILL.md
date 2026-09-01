---
name: schematic-site
description: Build or revise dark, multi-page static circuit-documentation sites with accessible clickable schematics, component-purpose pages, evidence links, BOMs, and build or verification guidance. Use for turning an existing electronics project, schematic, or circuit-design request into an explorable HTML site; use schematic-design first when the circuit itself still needs research or engineering.
---

# Schematic Site

Create a portable static site whose diagrams explain both connectivity and intent. A reader must be able to click or keyboard-activate every meaningful schematic component and reach a durable description of what it is, why it is present, how its value was chosen, and what could go wrong.

## Route the request

1. Read repository instructions and inspect the supplied project, schematic, BOM, calculations, simulations, notes, and inventory. Preserve the project's existing source formats.
2. Decide whether the input contains a sufficiently supported circuit design.
   - If yes, document it without silently redesigning it.
   - If the request asks for a new circuit, adaptation, reverse engineering, or unresolved component choices, use `$schematic-design` first. Treat its design dossier as the site source of truth.
   - If evidence conflicts or the design is incomplete, show the uncertainty in the site instead of inventing certainty.
3. Choose an output directory with the user. If none is specified, use a clearly named `site/` or `docs/site/` directory inside the supplied project when that does not conflict with existing conventions. Do not overwrite an unrelated site.

## Build the artifact

Read [references/site-contract.md](references/site-contract.md) before generating or changing a site. Start from [assets/starter-site/](assets/starter-site/) when it fits; adapt it rather than preserving sample content.

Required outcomes:

- Use multiple HTML files plus shared local CSS and JavaScript. The site must work from ordinary static hosting without a build service or remote runtime dependency.
- Provide a high-level signal-flow view and one or more detailed schematics. Split dense circuits by functional block rather than shrinking an entire design beyond legibility.
- Make each meaningful component a real SVG link with a visible focus state and a useful accessible name. JavaScript may enhance selection or highlighting, but navigation must still work when scripts fail.
- Give every component a stable reference designator and a detail destination. Explain identity, circuit role, value rationale, relevant operating conditions, interfaces, failure or substitution concerns, inventory/procurement status when known, and supporting evidence.
- Keep reference designators, values, net names, pin names, BOM rows, calculations, and prose synchronized. Do not use a visually plausible symbol as a substitute for an electrically accurate connection.
- Include overview, architecture or signal flow, detailed schematic sections, component explanations, BOM, build/bring-up guidance, verification results, risks or limitations, and sources when those subjects are relevant.
- Use the dark technical visual language from the starter: restrained charcoal surfaces, high-contrast text, condensed headings, monospaced identifiers, semantic wire colors, hairline rules, compact cards, and minimal animation. Clarity outranks decoration.
- Support narrow screens, zoom, horizontal overflow for wide drawings, reduced motion, visible keyboard focus, and print/PDF legibility.
- Keep source citations close to claims. Label calculations, simulation results, measurements, assumptions, and unverified statements distinctly.

Use component links like this, with paths adjusted for the page location:

```html
<a class="component-link" href="../components/r1.html"
   aria-label="R1, 100 kilohm input resistor">
  <g data-component-ref="R1">...</g>
</a>
```

Do not implement important navigation only through `onclick`, a JavaScript object, or an inspector panel. An optional inspector may preview the destination, but the link remains canonical.

## Verify locally

Run:

```bash
python3 <skill-dir>/scripts/validate_site.py <site-dir>
```

Then serve the site over HTTP and inspect it at desktop and narrow viewport widths. Exercise mouse and keyboard navigation, browser back/forward, direct component URLs, focus visibility, overflow, reduced motion, and all local links. If a browser controller is unavailable, report that limitation and still run structural validation; do not claim visual verification.

Check the generated result against the project's authoritative schematic or netlist. A passing HTML validator does not establish electrical accuracy.

## Review and publish

Before any upload, follow the mandatory staged gate in [references/review-and-publish.md](references/review-and-publish.md). The sequence is two independent reviews, fixes, one adversarial review, fixes, then separate accuracy and correctness reviews, fixes, and final validation. The main agent owns all dispositions and edits; reviewers return findings only.

Publishing is a distinct external mutation. Do not infer permission to upload merely because the user requested site generation. When publishing is explicitly requested, dry-run first with [scripts/publish_site.sh](scripts/publish_site.sh), show the resolved source and destination, obtain any authorization required by the active environment, then use `--apply`. Never guess the remote document root or publish an unreviewed build.

## Handoff

Report the site directory, entry page, validation commands and results, review stages completed, accepted and rejected material findings, unresolved electrical uncertainties, and publish URL or exact reason publishing did not occur.
