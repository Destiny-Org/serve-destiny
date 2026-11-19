# Using serve-destiny with Sublime Text
---

Requirments:
    - LSP Package: https://lsp.sublimetext.io/


Client Configuration:

```json
{
	"clients": {
		"serve-destiny": {
			"enabled": true,
			"command": ["C:/Users/MY_NAME_HERE/AppData/Roaming/code-d/bin/serve-destiny.exe"],
			"selector": "source.d",
			"settings": {
				"d.dcdServerPath": "C:/Users/MY_NAME_HERE/AppData/Roaming/code-d/bin/dcd-server.exe",
				"d.dcdClientPath": "C:/Users/MY_NAME_HERE/AppData/Roaming/code-d/bin/dcd-client.exe",

				// optional settings
				"d.servedReleaseChannel": "nightly",
				"d.aggressiveUpdate": false,
				"d.manyProjectsAction": "load",
				"d.enableAutoComplete": true,
				"d.completeNoDupes": true,
			}
		}
	}
}
```

Destiny files end in `.dd` (interface files in `.ddi`): open one, then use
View → Syntax → Open all with current extension as… → D, so Sublime Text
uses the D syntax (`source.d`) for them.
