# Site contract

Read this reference whenever creating or materially restructuring a schematic site.

## Information architecture

Use multiple durable pages. A typical small site contains:

```text
site/
├── index.html
├── schematic/
│   └── index.html
├── components/
│   ├── index.html
│   └── <reference>.html
├── bom/
│   └── index.html
├── build/
│   └── index.html
├── verification/
│   └── index.html
└── assets/
    ├── styles.css
    └── site.js
```

Combine or omit genuinely empty sections, but do not collapse the deliverable into one giant HTML file. A component page may cover a tightly coupled network such as a matched transistor pair or protection network; make that grouping explicit in its title and BOM mapping.

Every page must identify the project, revision or status, and whether values are calculated, simulated, measured, or provisional. Use relative links so the directory can move as one static artifact.

## Diagram behavior

Draw schematics as inline SVG so symbols, wires, text, accessibility attributes, and links remain inspectable. Use a consistent symbol library within the project. Set a `viewBox`; let CSS control rendered width.

Each meaningful component or intentional component group must be enclosed in an SVG `<a class="component-link">` whose `href` points to its detail page or detail-page fragment. Inside it, put the symbol and nearby reference/value label in a `<g data-component-ref="...">`. Give the link an `aria-label` containing the reference, value or part number, and plain-language identity.

Links must provide:

- visible hover and focus state that does not depend only on color;
- a minimum practical pointer target around small symbols;
- native Enter activation and browser history;
- a working destination without JavaScript;
- optional selection synchronization through `assets/site.js`.

Use `<title>` and `<desc>` inside each schematic SVG. Put a text summary adjacent to complicated diagrams. Wrap wide SVGs in a keyboard-focusable scroll region with an accessible label.

Do not hide connectivity under overlapping symbols or labels. Junction dots, net names, power domains, polarities, pin numbers, and off-page continuations must be unambiguous. Color is a secondary domain cue; line style, label, or symbol must carry the same meaning.

## Component detail contract

Each component destination declares its canonical identity on the page body, for example `<body data-component-page="R1">`. A page for an intentional group lists its references separated by spaces. Each destination explains, when relevant:

- reference designator and exact fitted value or part;
- component type, package, polarity, and pinout caveats;
- functional block and connections to surrounding nodes;
- purpose in this circuit, not a generic encyclopedia definition;
- value selection or operating-point calculation with units;
- tolerances, ratings, stress, headroom, or thermal concerns;
- failure symptoms and sensitive substitutions;
- inventory/procurement status and acceptable alternates;
- evidence: datasheet section, design calculation, simulation, or measurement;
- verification status and unresolved uncertainty.

Provide backlinks to the relevant detailed schematic and neighboring components. Component index and BOM rows must link to these same canonical pages.

## Visual language

The late-August reference files use a successful technical-instrument style:

- near-black canvas with slightly lifted charcoal panels;
- cool off-white body text and muted blue-gray annotations;
- orange for emphasis, with separate restrained colors for power, signal, control, timing, warning, and success domains;
- monospaced references/values, condensed display headings, and compact uppercase labels;
- thin borders, square or lightly rounded corners, small numerical section markers, and generous diagram whitespace;
- sticky contents or inspector only when it does not obscure the reading column;
- animation used to teach current or signal flow, always disabled under `prefers-reduced-motion` and never required to understand the circuit.

Maintain contrast and focus visibility. Do not import web fonts, analytics, UI frameworks, or third-party scripts unless the user specifically asks and the hosting/security constraints allow them. System font fallbacks are preferable for portable offline use.

## Content integrity

Create a cross-reference table while authoring: reference → schematic page → detail page → BOM row → calculation/source. Treat any missing edge as a defect.

Claims must carry one of these evidence classes in prose or nearby metadata:

- `measured`: observed on named hardware with conditions;
- `simulated`: produced by a named model and analysis;
- `calculated`: derived from stated values and equations;
- `datasheet`: taken from an identified table/figure/section;
- `assumed` or `provisional`: not yet verified.

Do not turn typical datasheet values into guarantees. Do not imply that HTML validation, link checking, or a visually clean schematic verifies the electrical design.

## Completion checks

- All pages and local assets load over a local HTTP server.
- Every `.component-link` works with mouse, Enter, direct URL, and browser back.
- All references, values, pins, and nets agree with authoritative design files.
- No text is clipped at 200% zoom; wide diagrams scroll instead of shrinking illegibly.
- A narrow viewport preserves navigation and component access.
- Focus order follows reading order and focus rings remain visible.
- Reduced-motion mode removes nonessential transitions and animations.
- Print CSS produces legible light-background pages or an intentionally verified dark print.
- Local structural validation passes with no errors.
