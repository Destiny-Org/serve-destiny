# Using serve-destiny with [Nova][1]
---

## Summary

The Nova extension **D-Velop** ([available][2] via the normal extension
facility) provides LSP support, syntax highlighting, folding and
indentation (via the Tree-sitter [D grammar][3]).

## Using serve-destiny

D-Velop offers to download its own language server, which is the upstream D
server, not serve-destiny. Decline that and point the extension at your
serve-destiny instead (see [Installation](README.md#Installation)), in the
extension's settings for a custom language server path.

[1]: https://nova.app "Nova Editor"
[2]: https://extensions.panic.com/extensions/tech.staysail/tech.staysail.ServeD/ "D-Velop extension for Nova"
[3]: https://github.com/gdamore/tree-sitter-d/ "Tree-sitter Grammar for D"
