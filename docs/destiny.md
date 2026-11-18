# serve-destiny: Destiny changes

The language server for Destiny. It speaks the Language Server Protocol, so it
works with any LSP editor: VS Code (code-d), Neovim/Vim, Emacs, Helix, Sublime
Text, Zed, Nova and Lite XL (setup guides: the `editor-*.md` files).

## Destiny features

- **Errors from the Destiny compiler, as you type.** About half a second
  after typing stops (and on save) the current text, saved or not, is checked
  with `destiny -o-`. That shows Destiny's own errors, such as code that is not
  memory safe under the `@safe` default, with the hints ("is `@safe` by
  default…") attached. D-Scanner's style checks still run as before.
- **Fate and druntime are found automatically** from `destiny.conf` (in the
  project, `$HOME`, next to the `destiny` binary, or `/etc`), so completion
  knows `std.*` and `fate.sys`.
- The compiler is `destiny` by default (`d.dmdPath`).
- A `// FLAGS: …` line near the top of a file adds compiler flags for that
  file (as in the Destiny examples), e.g. `// FLAGS: -revert=safedefault`.

- **Quick fixes for safety errors:** "Mark `f` @system", "Wrap in a @trusted
  lambda" (only if that code is safe for every input) and "Add `scope` to
  parameter `p`".
- **Hover says which safety applies:** written on the function, inferred
  (templates, `auto`), from a `@system:` label, or the `@safe` default.

New settings:

| Setting | Default | Meaning |
|---|---|---|
| `d.enableCompilerLinting` | `true` | check files with the Destiny compiler |
| `d.compilerArgs` | `[]` | extra flags for those checks |
| `d.dmdPath` | `"destiny"` | the compiler (path or name on `PATH`) |
| `d.dubPath` | `"des"` | DES, Destiny's package manager (path or name on `PATH`) |

## Building

serve-destiny is built with Destiny and Destiny's dub (`Destiny-Org/des`):

```
DFLAGS="-revert=safedefault -O -release -lowmem" \
    des build --compiler=destiny --build-mode=singleFile
```

- `-revert=safedefault`: the code (and its libraries) is written for upstream
  D's `@system` default.
- `--build-mode=singleFile`: one file per compiler run, so the build fits in
  4 GB of memory.
- No `-inline`: inlining makes the compiler analyse almost every imported
  function body for each file, which needs far more memory and makes no
  noticeable difference for a language server.
- `vendor/` holds third-party libraries that needed changes (see
  [vendored.md](vendored.md)).
- Destiny's own d-scanner and dub are path dependencies (`../d-scanner`,
  `../des` in `dub.selections.json`; `../../` in
  `workspace-destiny/dub.selections.json`), so check out
  `Destiny-Org/d-scanner` and `Destiny-Org/des` next to this repository:

  ```
  destiny-src/
    serve-destiny/
    d-scanner/
    des/
  ```

## Tests

- `des test` for each subpackage, as upstream.
- `test/destiny_smoke.py SERVER test/data/destiny_smoke.d` acts like an
  editor over LSP: it opens a file with a `@safe` error, expects a `destiny`
  diagnostic, sends the fixed (unsaved) text and expects the error to go,
  then asks for completions after `std.stdio.wri` and expects `writeln`.

## Continuous integration

Linux x86_64 only, built with Destiny (the only platform `destiny64` is made
for). `.github/actions/setup-destiny` installs the `destiny64` release from
`Destiny-Org/destiny` and builds Destiny's dub. `unittest.yml` checks out
d-scanner and dub next to this repository, runs the tests and the smoke test.
`releases.yml` attaches `serve-destiny_<tag>-linux-x86_64.tar.{xz,gz}` to the
published release. The Windows and macOS builds were dropped.

## How requests are dispatched

Each module with `@protocolMethod` / `@protocolNotification` functions ends
with `mixin RegisterProtocolHandlers!(that.module);`. That registers, once at
start-up, one small function per handler (parse the JSON parameters, call,
serialize the result), generated in the handler's own module. The router
(`served.serverbase`) only looks method names up in that table
(`served.utils.handlers`). Previously it looped over every handler at compile
time at each call site, which needed more than 8 GB to compile.

`@postProtocolMethod` observers are supported for `initialize` only (nothing
else uses them).

---|---|---|
| `d.enableCompilerLinting` | `true` | check files with the Destiny compiler |
| `d.compilerArgs` | `[]` | extra flags for those checks |
| `d.dmdPath` | `"destiny"` | the compiler (path or name on `PATH`) |

Build: see "Building" above (Destiny and DES), which produces the
`serve-destiny` binary.
