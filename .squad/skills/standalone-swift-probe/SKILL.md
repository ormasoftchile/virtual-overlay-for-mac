# Standalone Swift Probe Binary

Use this pattern when a macOS API behavior is unclear and the team needs real-machine evidence without touching the main app.

1. Create a tiny SwiftPM executable under `Prototypes/<ProbeFamily>/<probe-name>/`.
2. Keep it public-API-only unless the task explicitly authorizes private APIs; document private, deprecated, or undocumented surfaces in the README.
3. Include `Package.swift`, `Sources/<TargetName>/main.swift`, and a short `README.md` with purpose, run command, and manual actions.
4. Build from the probe folder with `swift build`, then run with `swift run`.
5. Capture stdout to a dated `results-YYYY-MM-DD.txt` beside the package.
6. Synthesize findings into the relevant `.squad/agents/<agent>/probes/` report before recommending product code changes.

For event-driven probes, support a bounded runtime so non-interactive runs complete and document which observations require manual interaction.
