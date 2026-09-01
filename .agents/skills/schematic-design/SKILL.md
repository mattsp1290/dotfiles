---
name: schematic-design
description: Research, adapt, and design evidence-backed electronic circuits, especially Eurorack and audio projects, with requirements, calculations, source provenance, parts-inventory reconciliation, schematics, simulation or bench plans, BOMs, and explicit uncertainty. Use when the electrical design itself is requested or not yet adequately established; do not use merely to restyle settled documentation.
---

# Schematic Design

Produce an engineering dossier that another person can inspect, simulate, prototype, and later turn into an interactive site. Optimize for traceability and buildability, not for a schematic that only looks plausible.

## Establish the design basis

1. Read all applicable repository instructions and inspect existing schematics, netlists, BOMs, source notes, simulations, test results, mechanical constraints, and parts inventories before proposing changes.
2. Extract the explicit requirements: function, signal and control ranges, supply rails, current budget, impedance, frequency or timing range, accuracy, noise, distortion, temperature behavior, protection, panel controls, mechanical limits, available parts, and intended construction method.
3. Ask only for missing decisions that materially change the topology or safety. Otherwise record a conservative assumption and its consequence.
4. Mark whether the task is documentation, adaptation, reproduction, reverse engineering, or a new design. Never present an inspired-by adaptation as the original circuit.

For substantial new designs or adaptations, read [references/design-evidence.md](references/design-evidence.md). For Eurorack work, also read [references/eurorack-checks.md](references/eurorack-checks.md).

## Research with provenance

Use current primary sources whenever the task depends on a published circuit, component behavior, interface specification, or product-specific claim. Prefer manufacturer datasheets and application notes, standards bodies, patents, service manuals, original schematics, and first-party engineering material. Secondary explanations may provide leads but cannot be the sole support for critical quantitative claims.

Record for each important source: title, issuer or author, revision/date when available, direct URL or repository path, pages/figures/tables used, and which claim it supports. Distinguish quoted values from derived values and engineering judgments. Respect copyright: cite original diagrams rather than copying a protected drawing wholesale; redraw only what the design needs and identify the source.

## Design in inspectable blocks

- Partition by function and define each block's input/output contract before selecting parts.
- Assign stable reference designators early. Keep them identical across schematic, calculations, simulations, BOM, test points, and eventual site.
- Show power pins, unused sections, decoupling, grounds, connectors, normalled contacts, polarity, pin numbers, and off-board wiring explicitly.
- Calculate nominal behavior and relevant corners. Check tolerance, temperature, bias/leakage, loading, headroom, common-mode/input/output limits, power dissipation, noise, stability, startup, fault current, and component ratings where applicable.
- Compare chosen parts against exact datasheet variants and packages. Do not transfer limits between superficially similar suffixes, families, or technologies.
- Reconcile selections against the supplied inventory. Separate `on hand`, `in transit`, `substitution`, `buy`, and `unknown`; never infer stock from a generic kit name without evidence.
- Prefer the repository's native schematic and simulation formats. Do not replace an existing KiCad or SPICE workflow with a prose-only drawing.

## Verify proportionally

Use algebraic checks, independent calculations, SPICE, ERC, or firmware tests as the circuit requires. State model provenance and simulation limits. Compare results to explicit acceptance criteria, not merely to whether a simulator converged.

For a hardware design that has not been built, say `designed` or `simulation-verified`, never `working` or `validated`. Provide a staged bring-up and measurement plan with safe current limits, expected test-point values or waveforms, calibration steps, and stop conditions. Treat mains, high voltage, high stored energy, batteries, lasers, RF transmitters, and other hazardous domains as requiring domain-specific review beyond this general skill.

## Deliverables

Fit the output to the repository, but for a new substantial design normally provide:

- design basis and assumptions;
- source/provenance table;
- architecture and block contracts;
- native schematic files and an export suitable for review;
- calculations with units and named variables;
- simulation inputs, models, commands, results, and acceptance criteria when applicable;
- BOM reconciled to inventory and substitutions;
- power budget, I/O contract, protection strategy, and test points;
- bring-up, calibration, and verification plan;
- open risks, unsupported claims, and decisions still requiring hardware evidence.

If the user also wants an explorable HTML artifact, hand this dossier to `$schematic-site`. The site may explain the design but must not become the only source of electrical truth.
