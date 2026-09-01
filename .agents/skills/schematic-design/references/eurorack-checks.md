# Eurorack design checks

Read this reference for Eurorack modules or adaptations intended to connect to a Eurorack system. Treat the project's stated interface contract as authoritative when it is stricter or more specific.

## Establish rather than assume

Record the exact case power system, rail voltages, connector orientation/keying, allowed current, module width/depth, panel grounding scheme, and target input/output ranges. Eurorack practice varies; do not present a common convention as a universal guarantee.

For every jack, identify:

- expected signal type and nominal range;
- credible external range and fault range;
- input impedance or output impedance;
- DC coupling, polarity, offset, and bandwidth;
- normalled/switch contact behavior when unpatched;
- protection behavior when the module is powered off;
- whether the jack sleeve, panel, chassis, analog ground, and digital ground connect and where.

## Power and protection

- Show the power header pin numbering and orientation in the repository's chosen convention. Provide reverse-connection strategy and a current-limited first-power procedure.
- Budget both rails separately, including indicators, startup, maximum control settings, digital activity, external loads, and regulator losses.
- Check every device's absolute maximum, recommended operating range, input common-mode range, and output swing against the actual rails and node voltages.
- Put local decoupling at each IC and explain bulk capacitance and rail filtering. Include unused op-amp or logic sections and defined logic states.
- Analyze patching faults: output-to-output contention, external voltage at an unpowered input, shorts to ground or rails, negative voltage on logic/ADC pins, and cable insertion transients.
- Confirm resistor power, diode current, regulator and transistor dissipation at relevant faults. “Protected” requires calculated current and a rated path.

## Analog and timing behavior

- State calibration points and how component tolerance or temperature affects them.
- Check headroom across the full waveform and control range, not only at zero signal.
- For oscillators and timing cores, evaluate startup, frequency span, reset behavior, waveform amplitude/offset, tracking law, temperature sensitivity, sync behavior, and control feedthrough.
- For envelopes and VCAs, evaluate trigger/gate thresholds, retrigger behavior, time ranges, residual CV, bleed, distortion, and interaction among controls.
- For digital interfaces, verify thresholds, level shifting, boot states, sample rate, alias filtering, latency/jitter, and firmware pin conflicts.

## Bring-up

Create test points and expected values for power-off resistance checks, current-limited power-up, rails/references, static operating points, functional stimulus, calibration, and full-range sweeps. Name stop conditions such as excess current, rail collapse, hot parts, unexpected DC or DC outside the documented output contract, unintended oscillation, or unexpected latch-up.

Label bench observations with instrument, probe/load, supply conditions, control settings, temperature when relevant, and board revision. Do not generalize a single prototype result to all component corners.
