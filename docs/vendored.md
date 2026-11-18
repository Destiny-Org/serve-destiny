# Vendored libraries (`vendor/`)

Third-party libraries kept in this repository because they need changes to
build with Destiny. `dub.selections.json` points at these folders.

| Library | Version | Change |
|---|---|---|
| `emsi_containers` | 0.9.0 | `TTree` node rotations are `@trusted` instead of `@safe`: they store `&this` of allocator-owned (heap) nodes, which Destiny's always-on scope checking cannot prove safe. |

D-Scanner and dub are not vendored: serve-destiny uses Destiny's own
repositories, the sibling folders `../d-scanner` (with the same `@trusted` fix
in `NoLint.push`) and `../des` (Destiny's dub, also used as a library here).
The folders must sit side by side, as described in destiny_engine's
`docs/development.md`.
