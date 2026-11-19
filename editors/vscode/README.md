# Destiny for Visual Studio Code

Support for the Destiny programming language in VS Code (and VSCodium,
Cursor and other VS Code-based editors):

- **Destiny file icon** for `.dd` and `.ddi` files in the file tree and tabs.
- **Syntax highlighting**, including Destiny's `@safe` / `@trusted` /
  `@system` attributes.
- **Errors as you type, with `fix:` hints and quick fixes**, plus
  completion, hover and go-to-definition, from
  [serve-destiny](https://github.com/Destiny-Org/serve-destiny).

## Requirements

Download `destiny`, `des` and `serve-destiny` from their GitHub releases and
put them on your `PATH`, or set their paths in the settings below.

## Settings

| Setting | Default | Meaning |
|---|---|---|
| `destiny.serverPath` | `serve-destiny` | Path to the serve-destiny language server |
| `destiny.compilerPath` | `destiny` | Path to the destiny compiler |
| `destiny.desPath` | `des` | Path to des, the package manager |

## Building the extension

From this folder:

```
npm install
npx vsce package
```

This makes `destiny-<version>.vsix`. Install it with **Extensions → … →
Install from VSIX**, or `code --install-extension destiny-<version>.vsix`.

## License

Mozilla Public License 2.0; see [LICENSE](LICENSE).
