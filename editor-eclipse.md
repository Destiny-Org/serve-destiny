# Using serve-destiny with [Eclipse][1]
---

Eclipse talks to language servers through LSP4E, which ships with the
"Eclipse IDE for Java/C/C++ Developers" packages (2021 and newer). If your
Eclipse lacks it, install **LSP4E** from Help → Eclipse Marketplace.

Put `serve-destiny`, `destiny` and `des` on your `PATH` first.

1. **Tell Eclipse what a Destiny file is.**
   Window → Preferences → General → Content Types → select **Text** →
   Add Child… → name it `Destiny source`. With it selected, under
   *File associations* click Add… and enter `*.dd`, then again for `*.ddi`
   (and `*.d` / `*.di` if you also open D files).

2. **Open those files in the Generic Editor.**
   Preferences → General → Editors → File Associations → add `*.dd` (and
   `*.ddi`) and set **Generic Text Editor** as the default.

3. **Create a launcher for serve-destiny.**
   Run → External Tools → External Tools Configurations… → Program → New.
   Name it `serve-destiny`, set *Location* to the full path of the
   `serve-destiny` program, and click Apply (don't run it).

4. **Connect the two.**
   Preferences → Language Servers → Add… → pick the `Destiny source` content
   type and the `serve-destiny` launch configuration → OK.

Open a `.dd` file: errors (with their `fix:` hints), quick fixes, hover,
completion and go-to-definition now come from serve-destiny.

Syntax colouring is separate from the language server. For it, install
**TM4E** (Eclipse TextMate support) from the Marketplace and add a D TextMate
grammar under Preferences → TextMate → Grammar.

[1]: https://eclipseide.org "Eclipse IDE"
