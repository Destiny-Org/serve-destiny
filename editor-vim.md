# serve-destiny with Vim / NeoVim

## Using *ycmd*

[Download or build serve-destiny](README.md#Installation) and edit your `.vimrc`.

```vimrc
let g:ycm_language_server = [
            \ {
            \     'name': 'd',
            \     'cmdline': ['path/to/your/serve-destiny/binary'],
            \     'filetypes': ['d'],
            \ }]
```

Familiarize yourself with how ycmd handles `.ycm_extra_conf.py` files.
For serve-destiny, it is important that you give ycmd the LSP arguments in
the right format. The basic setup for establishing autocomplete with
the D standard library needs the path (or, if multiple paths, an array
of them) to your D standard library on your system.

```python
def Settings(**kwargs):
    lang = kwargs['language']
    if lang == 'd':
        return { 'ls': {
                   'd': { 'stdlibPath': '/path/to/your/stdlib' }
                   # In case you need multiple paths, do
                   # 'd' : { 'stdlibPath': ['/path/to', '/your/stdlibs']}
                   # For other config options, see README.md
                 }
               }
    else:
        return {}
```

Put this in a file called `.ycm_extra_conf.py` and save it in your
project root or move it further up the folder hierarchy, if you know
what you are doing.

## Using *coc's*

### Through *coc-settings.json*

(The `coc-dlang` extension installs the upstream D server, not serve-destiny,
so configure serve-destiny by hand.)

First [download or build serve-destiny](README.md#Installation)

A `coc-settings.json` file looking like this works well (you can open it with `:CocConfig`)

```js
{
	"languageserver": {
		"d": {
			"command": "PATH_TO_SERVE_D_EXECUTABLE/serve-destiny",
			"filetypes": ["d"],
			"trace.server": "on",
			"rootPatterns": ["dub.json", "dub.sdl"],
			"initializationOptions": {
			},
			"settings": {
			}
		}
	},
	"suggest.autoTrigger": "none",
	"suggest.noselect": false
}
```

## Using *nvim-lspconfig*

Neovim has a builtin LSP client and official LSP configs for it
[here](https://github.com/neovim/nvim-lspconfig).

After installing `nvim-lspconfig` using your preferred plugin manager, you must
load serve-destiny, like the following:

```lua
vim.lsp.enable('serve_d')
```

Documentation for configuring the LSP within Neovim can be found
[here](https://neovim.io/doc/user/lsp/#lsp-config) or by running `:help lsp` from
within Neovim.

### User Configuration

`serve-destiny` comes pre-packaged with some server-specific settings. You can find a description of such settings in the README ("Configuration").

For example, let's assume that you want to change the braces style so that they are on the same line as a function definition.

`dfmt` is used by `serve-destiny` by default; it allows the option for the `"stroustrup"` style.

```lua
vim.lsp.config('serve_d', {
  settings = {
    dfmt = {
      braceStyle = "stroustrup",
    },
  },
})
```

## Destiny file types

Destiny source files end in `.dd` (interface files in `.ddi`). Tell Vim they
use the `d` file type, so the settings above apply to them:

```vim
autocmd BufRead,BufNewFile *.dd,*.ddi set filetype=d
```
