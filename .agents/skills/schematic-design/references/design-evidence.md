# Design evidence workflow

Read this reference for substantial new circuits, adaptations, or reverse-engineering tasks.

## Design basis record

Keep one explicit table for requirements and assumptions. Include target, tolerance or acceptance criterion, source, and status. Cover electrical interfaces, supply, function, environmental/mechanical constraints, inventory constraints, and the intended evidence level.

For a reproduction or adaptation, maintain a lineage table:

| Original block or value | Primary source | Preserved or changed | Reason | Consequence | Verification |
|---|---|---|---|---|---|

This prevents folklore, later modifications, and the new design from being blended into a false “original schematic.”

## Calculations

Use named variables, units, equations, substitutions, results, and interpretation. Retain enough precision to reproduce the result, then round component choices deliberately. Check the cases that can change a design decision, which may include:

- min/typ/max source and load conditions;
- resistor/capacitor tolerance and temperature drift;
- semiconductor gain, offset, leakage, saturation, forward voltage, and safe operating area;
- op-amp common-mode range, output swing, input bias, noise, bandwidth, slew, capacitive-load stability, and phase reversal;
- regulator dropout, dissipation, transient behavior, reverse current, and startup;
- logic thresholds, output drive, power-up state, level compatibility, edge rate, and timing margin;
- connector faults, shorts, reverse supply, overvoltage, hot plug, and ESD strategy;
- power budget at idle, expected maximum, and credible fault.

Do not perform exhaustive math that cannot affect the result. State which corners were intentionally not analyzed and why.

## Models and simulation

Record model filename, source, version/date if available, mapping to the exact part, and any edits. Keep simulation inputs and commands versioned. Use multiple analyses when relevant: operating point, transient, AC, noise, parameter sweep, temperature, and tolerance/Monte Carlo.

Define acceptance criteria before interpreting results. Save concise machine-readable outputs when the repository has a checking script. Results from a generic model may be exploratory evidence rather than validation. A non-convergent run is a failed analysis and provides no circuit-performance evidence; diagnose it rather than citing it.

## Inventory and substitutions

Parse inventories by exact manufacturer part number, value, tolerance, voltage/power rating, package, quantity, and status. Preserve the inventory's date and distinguish ordered from physically received.

For a substitution, compare the parameters that matter in this circuit and record pinout/package differences. “Same category” is not evidence of interchangeability. Re-run calculations or simulation affected by the substitute.

## Verification matrix

Map each requirement to one or more methods: inspection, calculation, ERC, simulation, bench measurement, calibration, or destructive/fault testing. Include expected result, tolerance, equipment, setup, and status.

Separate:

- design-complete but untested;
- calculation-checked;
- simulation-verified;
- prototype-measured;
- production-verified.

Never promote a claim to a stronger state without its evidence artifact.
