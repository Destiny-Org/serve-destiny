# serve-destiny

A [Language Server Protocol](https://microsoft.github.io/language-server-protocol/)
server for [Destiny](https://github.com/Destiny-Org/destiny). It gives any LSP
editor completion, go-to-definition, hover, formatting, linting and Destiny's
own checks.

## Features

- **Destiny errors while you type.** Each file is checked with the `destiny`
  compiler (500 ms after you stop typing, and on save), including unsaved
  changes. Errors such as `@safe` violations and scope errors appear in the
  editor, with the compiler's explanation lines and `fix:` suggestion.
- **Quick fixes** for Destiny errors: mark a function `@system`, wrap the code
  in `@trusted`, or add `scope` to a parameter.
- **Hover** shows whether a function is `@safe`, `@trusted` or `@system`, and
  why.
- Completion, go-to-definition and symbol search (DCD), formatting (dfmt),
  linting (D-Scanner), and DES project support (`dub.json` / `dub.sdl`).

## Usage

Destiny source files end in `.dd` and interface files in `.ddi` (D's `.d` and
`.di` also work). Associate those extensions with Destiny in your editor; in
VS Code, add to your settings:

```json
"files.associations": { "*.dd": "destiny", "*.ddi": "destiny" }
```

**VS Code:** install the Destiny extension from
[`editors/vscode`](editors/vscode) (file icon, highlighting, and this server).

Any editor with an LSP client can run `serve-destiny` over stdio. Guides for
some editors:

* [vim](editor-vim.md)
* [sublime text](editor-st.md)
* [emacs](editor-emacs.md)
* [Helix](editor-helix.md)
* [Nova](editor-nova.md)
* [Lite-XL](editor-lite-xl.md)
* [Zed](editor-zed.md)
* [Eclipse](editor-eclipse.md)

serve-destiny needs `destiny` (and `des` for projects) on `PATH`, or set
`d.dmdPath` and `d.dubPath` to their paths.

Settings for the Destiny checks:

| Setting | Default | Meaning |
|---|---|---|
| `d.enableCompilerLinting` | `true` | check files with the Destiny compiler |
| `d.compilerArgs` | `[]` | extra flags for those checks |
| `d.dmdPath` | `"destiny"` | the compiler (path or name on `PATH`) |
| `d.dubPath` | `"des"` | DES, Destiny's package manager |

A file can add its own compiler flags with a `// FLAGS: ...` comment.

### Project Layout

- [`serve-destiny:http`](./http) - Downloads a file over HTTP with progress using WinHTTP on Windows and the dub requests library on other platforms.
- [`serve-destiny:lsp`](./lsp) - LSP protocol types and RPC primitives
- [`serve-destiny:serverbase`](./serverbase) - LSP server basics for quickly creating an LSP server for any language.
- [`serve-destiny:dcd`](./dcd) - DCD client using direct communication (without spawning dcd-client) for lower latency
- [`serve-destiny:workspace-destiny`](./workspace-destiny) - Implementation of core D functionality and source code processing using libdparse, dfmt, D-Scanner and DCD.
- [`source/`](./source) - Maps LSP commands and state to serve-destiny:workspace-destiny functionality.

### Command Line options

serve-destiny offers the following command line options to allow the LSP client to configure serve-destiny on startup:

| Option | Default | Description |
| ------ | ------- | ----------- |
| `-r` / `--require` | [] | (allows multiple, optional) List of options which this serve-destiny version needs to implement. serve-destiny will intentionally crash on startup if one of the given options is not supported by this version. Specifying or not specifying them will not change anything on runtime. Implemented features: `d` (PoC / unneeded), `workspaces` (multi-workspace support) |
| `-p` / `--provide` | [] | (allows multiple, optional) List of options to affect behavior of serve-destiny. Use this to indicate support for special editor features/extensions not covered by the LSP spec. Supported values: (see provides list below) |
| `-v` / `--version` | n/a | Prints the version to stdout and exists |
| `--logfile` | n/a | Overrides the logging output to log to a file instead of stderr for debug logs |
| `--loglevel` | `verbose` for debug/nightly builds, otherwise `info` | Changes the minimum log level when messages are logged. See `serve-destiny --help` for possible values |
| `--lang` | `en` | Changes the language of GUI messages to a supported translation |
| `--wait` | `false` | Waits for one second before starting (useful to be able to attach when debugging) |

#### `--provide` values

The following provide values are supported by serve-destiny and will improve interop with the editor:

**`--provide http`**

When this provide flag is set, serve-destiny will send a request to the client when it wants to download a file (commonly DCD server files) using the `coded/interactiveDownload` request.

If this is not set, an internal download function is used which calls `coded/logInstall` on the client on every progress event.

**`--provide implement-snippets`**

If this is set, the `served/implementMethods` request will return TextEdits with snippet strings inside of them as defined by vscode.

Additionally the code action that would normally just insert a regular string will call the `code-d.implementMethods` command if this is set, which is expected to then call `served/implementMethods`, so that snippets are supported.

**`--provide context-snippets --provide default-snippets`**

If this is set, auto completion requests will also return built-in and custom defined snippets. Will register snippets for popular DUB dependencies that are built into serve-destiny.

NOTE: these flags will be enabled by default in serve-destiny v0.9.0 and become obsolete then.

<!-- TODO: --provide test-runner + commands to implement -->

### Custom requests/notifications

serve-destiny defines a variety of custom requests and notifications for better editor integration. All requests starting with `coded/` are sent from serve-destiny to the client and all requests starting with `served/` are sent from client to serve-destiny at any time.

serve-destiny internally handles an active instance which is the instance where last a relevant command has been run. (such as auto complete) It will be used for some commands.

#### Request `served/sortImports`

**Parameter**: `SortImportsParams`

**Returns**: `TextEdit[]`

Command to sort all user imports in a block at a given position in given code. Returns a list of changes to apply. (Replaces the whole block currently if anything changed, otherwise empty)

```ts
interface SortImportsParams
{
	/** Text document to look in */
	textDocument: TextDocumentIdentifier;

	/** Location of cursor as standard offset, -1 for entire document */
	location: number;
}
```

#### Request `served/implementMethods`

**Parameter**: `ImplementMethodsParams`

**Returns**: `TextEdit[]`

Implements the interfaces or abstract classes of a specified class/interface. The given position must be on/inside the identifier of any subclass after the colon (`:`) in a class definition.

```ts
interface ImplementMethodsParams
{
	/** Text document to look in */
	textDocument: TextDocumentIdentifier;

	/** Location of cursor as standard offset */
	location: number;
}
```

#### Request `served/restartServer`

**Parameter**: none

**Returns**: `true`

Restarts all DCD servers started by this serve-destiny instance. Returns `true` once done.

#### Notification `served/killServer`

**Parameter**: none

Kills all DCD servers started by this serve-destiny instance.

#### Request `served/addDependencySnippet`

**Parameter**: `AddDependencySnippetParams`

**Returns**: `boolean`

Registers a snippet across the whole serve-destiny application which may be limited to given grammatical scopes.

Requires `--provide context-snippets`

Returns false if SnippetsComponent hasn't been loaded yet, otherwise true.

#### Notification `served/updateDCD`

**Parameter**: none

Manually triggers a DCD update either by compiling from source or downloading prebuilt binaries depending on the host system and serve-destiny. Excessively calls the `coded/logInstall` notification.

#### Request `served/listConfigurations`

**Parameter**: none

**Returns**: `string[]`

Returns an empty array if there is no active instance or if it doesn't have dub.

Otherwise returns the names of available [configurations](https://dub.pm/package-format-json.html#configurations) in dub.

#### Request `served/switchConfig`

**Parameter**: `string`

**Returns**: `bool`

Sets the current dub configuration for building and other tools. Returns true on success.

#### Request `served/getConfig`

**Parameter**: none

**Returns**: `string`

Returns the current dub configuration or null if there is no dub in the active instance.

#### Request `served/listArchTypes`

**Parameter**: `ListArchTypesParams`

**Returns**: `string[] | ArchTypeInfo[]`

Returns an empty array if there is no active instance or if it doesn't have dub.

Otherwise returns the names of available architectures in dub. (e.g. x86 or x86_64)

```ts
interface ListArchTypesParams
{
	/** If true, return ArchTypeInfo[] with meanings instead of string[] */
	withMeaning?: boolean;
}

interface ArchTypeInfo
{
	/** The value to use with a switchArchType call / the value DUB uses. */
	value: string;
	/** If not null, show this string in the UI rather than value. */
	label: string | null;
}
```

#### Request `served/switchArchType`

**Parameter**: `string`

**Returns**: `bool`

Sets the current architecture for building and other tools. Returns true on success.

#### Request `served/getArchType`

**Parameter**: none

**Returns**: `string`

Returns the current dub architecture or null if there is no dub in the active instance.

#### Request `served/listBuildTypes`

**Parameter**: none

**Returns**: `string[]`

Returns an empty array if there is no active instance or if it doesn't have dub.

Otherwise returns the names of available [build types](https://dub.pm/package-format-json.html#build-types) in dub.

#### Request `served/switchBuildType`

**Parameter**: `string`

**Returns**: `bool`

Sets the current DES build type for building and other tools. Returns true on success.

#### Request `served/getBuildType`

**Parameter**: none

**Returns**: `string`

Returns the current DES build type or null if there is no DES project in the active instance.

#### Request `served/getCompiler`

**Parameter**: none

**Returns**: `string`

Returns the name of the current compiler.

#### Request `served/switchCompiler`

**Parameter**: `string`

**Returns**: `bool`

Sets the current compiler to use in dub for building and other tools. Returns true on success.

#### Request `served/addImport`

**Parameter**: `AddImportParams`

**Returns**: `ImportModification`

Parses the source code and returns code edits how to insert a given import into the code.

```ts
interface AddImportParams
{
	/** Text document to look in */
	textDocument: TextDocumentIdentifier;
	/** The name of the import to add */
	name: string;
	/** Location of cursor as standard offset */
	location: number;
	/** if `false`, the import will get added to the innermost block */
	insertOutermost?: boolean = true;
}

interface ImportModification
{
	/** Set if there was already an import which was renamed. (for example import io = std.stdio; would be "io") */
	rename: string;

	/** Array of replacements to add the import to the code */
	replacements: CodeReplacement[];
}

interface CodeReplacement
{
	/**
	 * Range what to replace. If both indices are the same its inserting.
	 *
	 * This value is specified as bytes offset from the UTF-8 source.
	 */
	size_t[2] range;

	/** Content to replace it with. Empty means remove. */
	string content;
}
```

#### Request `served/updateImports`

**Parameter**: `UpdateImportsParams`

**Returns**: `boolean`

Refreshes the dub dependencies from the local filesystem. Triggers a `coded/updateDubTree` notification on success and updates imports in DCD.

Returns true on success.

```ts
interface UpdateImportsParams
{
	/// set this to false to not emit progress updates for the UI
	reportProgress?: bool;
}
```

#### Request `served/listDependencies`

**Parameter**: `string` packageName

**Returns**: `DubDependency[]`

Lists the dependencies of a given dub package name. If no package name is given (empty string) then all dependencies of the current instance will be listed.

```ts
interface DubDependency
{
	/** The name of this package */
	name: string;
	/** The installed version of this dependency or null if it isn't downloaded/installed yet */
	version: string;
	/** Path to the directory in which the package resides or null if it's not stored in the local file system. */
	path: string;
	/** Description as given in dub package file */
	description: string;
	/** Homepage as given in dub package file */
	homepage: string;
	/** Authors as given in dub package file */
	authors: string[];
	/** Copyright as given in dub package file */
	copyright: string;
	/** License as given in dub package file */
	license: string;
	/** List of the names of subPackages as defined in the package */
	subPackages: string[];
	/** `true` if this dependency has other dependencies */
	hasDependencies: boolean;
	/** `true` if no package name was given and thus this dependency is a root dependency of the active project. */
	root: boolean;
}
```

#### Request `served/buildTasks`

**Parameter**: none

**Returns**: `Task[]`

Returns a list of build tasks for all dub instances in the project. Currently each with Build, Run, Rebuild and Test commands.

```ts
enum TaskGroup
{
	clean = "clean",
	build = "build",
	rebuild = "rebuild",
	test = "test"
}

interface Task
{
	/// the default JSON task
	definition: any;
	/// global | workspace | uri of workspace folder
	scope: string;
	/// command to execute
	exec: string[];
	/// name of the task
	name: string;
	/// true if this is a background task without shown console
	isBackground: boolean;
	/// Task source extension name
	source: string;
	/// clean | build | rebuild | test
	group: TaskGroup;
	/// problem matchers to use
	problemMatchers: string[];
}
```

#### Notification `served/convertDubFormat`

**Params**: `DubConvertRequest`

Starts a conversion of a dub.json/dub.sdl file to a given other format. Shows an error message in the UI if unsuccessful and triggers a `workspace/applyEdit` command when successful with the new content.

```ts
interface DubConvertRequest
{
	/** Text document to look in */
	textDocument: TextDocumentIdentifier;
	/** The format to convert the dub recipe to. (json, sdl) */
	newFormat: string;
}
```

#### Notification `served/installDependency`

**Params**: `InstallRequest`

Adds a dependency to the dub recipe file of the currently active instance (respecting indentation) and calls dub upgrade and updates imports afterwards.

Writes changes to the file system.

```ts
interface InstallRequest
{
	/** Name of the dub dependency */
	name: string;
	/** Version to install in the dub recipe file */
	version: string;
}
```

#### Notification `served/updateDependency`

**Params**: `UpdateRequest`

Changes a dependency in the dub recipe file of the currently active instance (respecting indentation) to the given version and calls dub upgrade and updates imports afterwards.

Does nothing if the dependency wasn't found in the dub recipe.

Writes changes to the file system.

```ts
interface UpdateRequest
{
	/** Name of the dub dependency */
	name: string;
	/** Version to install in the dub recipe file */
	version: string;
}
```

#### Notification `served/uninstallDependency`

**Params**: `UninstallRequest`

Removes a dependency from the dub recipe file of the currently active instance and calls dub upgrade and updates imports afterwards.

Writes changes to the file system.

```ts
interface UninstallRequest
{
	/** Name of the dub dependency */
	name: string;
}
```

#### Notification `served/doDscanner`

**Params**: `DocumentLinkParams`

Manually triggers DScanner linting on the given file. (respecting user configuration)

#### Request `served/searchFile`

**Params**: `string` query

**Returns**: `string[]`

Searches for a given filename (optionally also with subfolders) and returns all locations in the project and all dependencies including standard library where this file exists.

#### Request `served/findFilesByModule`

**Params**: `string` module

**Returns**: `string[]`

Lists all files with a given module name in the project and all dependencies and standard library.

#### Request `served/getDscannerConfig`

**Params**: `DocumentLinkParams`

**Returns**: `DScannerIniSection[]`

Returns the current D-Scanner configuration for a given URI.

```ts
/// An ini section of the dscanner.ini which is written in form [name]
interface DScannerIniSection
{
	/// A textual human readable description of the section
	description: string;
	/// The name of the section as written in the ini
	name: string;
	/// Features which are children of this section
	features: DScannerIniFeature[]
}

/// A single feature in a dscanner.ini which can be turned on/off
interface DScannerIniFeature
{
	/// A textual human readable description of the value
	description: string;
	/// The name of the value
	name: string;
	/// Enables/disables the feature or enables it with being disabled in unittests
	enabled: "disabled" | "enabled" | "skip-unittest"
}
```

#### Request `served/getActiveDubConfig`

**Params**: none

Returns dub information for the currently active project (dub project where last
file was edited / opened / etc)

**Returns**: at least

```js
{
    "packagePath": string,
    "packageName": string,
    "targetPath": string,
    "targetName": string,
    "workingDirectory": string,
    "mainSourceFile": string,

    "dflags": string[],
    "lflags": string[],
    "libs": string[],
    "linkerFiles": string[],
    "sourceFiles": string[],
    "copyFiles": string[],
    "versions": string[],
    "debugVersions": string[],
    "importPaths": string[],
    "stringImportPaths": string[],
    "importFiles": string[],
    "stringImportFiles": string[],
    "preGenerateCommands": string[],
    "postGenerateCommands": string[],
    "preBuildCommands": string[],
    "postBuildCommands": string[],
    "preRunCommands": string[],
    "postRunCommands": string[]
}
```

#### Request `served/getProfileGCEntries`

**Params**: none

Returns all profilegc.log entries parsed and combined.

**Returns**: `ProfileGCEntry[]`

```js
interface ProfileGCEntry
{
	bytesAllocated: number;
	allocationCount: number;
	type: string; /// the function and/or type name
	uri: string; /// absolute, normalized uri
	displayFile: string; /// as parsed from file
	line: number; /// 1-based line number
}
```

#### Notification `served/didChangeConfiguration`

**Params**: Exactly as for `workspace/didChangeConfiguration`

This notification triggers the use of alternate configuration notifications.
Once this is received, the server will ignore `workspace/didChangeConfiguration`
notifications.  This mechanisms exists to support some client/plugin combinations
where the plugin needs more direct control over the configuration.

#### Request `served/getInfo`

**Params**: `ServedInfoParams`

Returns all profilegc.log entries parsed and combined.

**Returns**: `ServedInfoResponse`

```js
interface ServedInfoParams
{
	includeConfig?: boolean;
	includeIndex?: boolean;
	includeTasks?: boolean;
}

interface ServedInfoResponse
{
	/** Same as in the initialized response. (the LSP server info) */
	serverInfo: ServerInfo;

	/**
	 * Only included if `ServedInfoParams.includeConfig` is true.
	 *
	 * Contains the entire config object, e.g. `{"d":{...}, ...}`
	 */
	currentConfiguration?: Configuration;

	/**
	 * Only included if `ServedInfoParams.includeIndex` is true.
	 * Key: module, Value: modules that depend on the (key) module.
	 * This is only the module index for the active workspace.
	 */
	{ [module: string]: string[] }?: moduleIndex;

	/**
	 * Describes the global workspace, same type as in
	 * `coded/changedSelectedWorkspace`
	 */
	globalWorkspace: WorkspaceState;

	/** Describes all available workspaces. */
	workspaces: WorkspaceState[];

	/**
	 * First index inside the `workspaces` array sent along this value, where
	 * `selected` is set to true, or -1 for global workspace.
	 */
	selectedWorkspaceIndex: number;

	/**
	 * Only included if `ServedInfoParams.includeTasks` is true.
	 *
	 * List of currently running and recently done LSP requests and tasks
	 */
	runningTasks: {
		/** task name (in most cases function name or LSP request name) */
		name: string,
		/** Number of seconds before now (float) when the task was queued */
		queued: number,
		/** Number of seconds before now (float) when the task was first started */
		started: number,
		/** Number of seconds before now (float) when the task ended - 0 for running tasks */
		ended: number,
		/** true if currently ongoing (e.g. yielding) */
		running: boolean,
		/** Number of (re)entries */
		numSteps: number,
		/** Number of seconds that this fiber was running in total */
		timeSpent: number,
	}[]
}
```

#### Request `served/forceLoadProjects`

**Params**: `string[]`

Forces the load of projects, regardless of manyProjects limit or action configuration of the given file paths. Returns true if successful, false otherwise, for each item in the params array in order that was given in.

**Returns**: `bool[]`

------

#### Client notification `coded/updateSetting`

**Params**: `UpdateSettingParams`

Tells the client to update a user or workspace setting. This is done for updating the dcdClientPath and dcdServerPath on installation.

```ts
interface UpdateSettingParams
{
	/** The configuration section to update in (e.g. "d" or "dfmt") */
	section: string;
	/** The value to set the configuration value to */
	value: any;
	/** `true` if this is a configuration change across all instances and not just the active one */
	global: bool;
}
```

#### Client notification `coded/logInstall`

**Params**: `string` message

Instructs the client to log a message that has something to do with the installation routine of serve-destiny or dependencies.

#### Client notification `coded/initDubTree`

**Params**: none

Tells the client that dub has been loaded and the dependency tree can now be fetched.

#### Client notification `coded/updateDubTree`

**Params**: none

Tells the client that dub dependencies have been reloaded and should be redisplayed.

#### Client notification `coded/changedSelectedWorkspace`

**Params**: `WorkspaceState`

Tells the client when the active instance changed.

```ts
interface WorkspaceState
{
	/** URI to the workspace folder */
	uri: string;
	/** name of the workspace folder (or internal placeholder) */
	name: string;
	/** true if this instance has been initialized */
	initialized: boolean;
	/** true if this is the active instance */
	selected: boolean;
	/**
	 * May contain errors that are pending and will be shown once the user with
	 * this workspace.
	 *
	 * Key: URI folder or file in which startup issues occured. (compare with
	 * startsWith)
	 * Value: human readable message.
	 * */
	pendingErrors: { [folderUri: string]: string };
}
```

#### Client notification `coded/skippedLoads`

**Params**: `InteractiveDownload`

Tells the client that project loading was skipped for the given path(s). The client may then ask the user or query configuration if the paths should be loaded or skipped. When requesting to load projects, pass these roots as arguments to the reqeust `served/forceLoadProjects`.

Otherwise, project loading is blocking and asks the client using a message box for each lazy-loaded project. IDE functionality is otherwise limited while these message boxes are open.

This must be implemented if `--provide async-ask-load` is given in the command line, otherwise this is not called.

```ts
interface SkippedLoadsNotification
{
	/** List of folder file paths */
	roots: string[];
}
```

#### Client request `coded/interactiveDownload`

**Params**: `InteractiveDownload`

**Returns**: `boolean`

Instructs the client to download a file into a given output path using download UI.

This must be implemented if `--provide http` is given in the command line, otherwise this is not called.

```ts
interface InteractiveDownload
{
	/** The URL to download */
	url: string;

	/** The title to show in the UI popup for this download */
	title?: string;

	/** The file path to write the downloaded file to */
	output: string;
}
```

### User Configuration

The server reads the `d.*` settings; the Destiny ones are listed under "Usage" above.

## Installation

Download `serve-destiny_<version>-linux-x86_64.tar.xz` from this repository's
[releases](https://github.com/Destiny-Org/serve-destiny/releases) and put
`serve-destiny` on your `PATH`. Only Linux x86_64 is supported, like Destiny.

## Building

serve-destiny is built with Destiny and DES. Check out
[d-scanner](https://github.com/Destiny-Org/d-scanner) and
[des](https://github.com/Destiny-Org/des) next to this repository, then:

```
DFLAGS="-revert=safedefault -O -release -lowmem" \
    des build --compiler=destiny --build-mode=singleFile
```

`--build-mode=singleFile` and `-lowmem` keep the build within 4 GB of memory.

## Issues

Report issues at https://github.com/Destiny-Org/serve-destiny/issues.

## License

Mozilla Public License 2.0; see [LICENSE](LICENSE) and [NOTICE](NOTICE). The original
serve-d files stay under the MIT License ([LICENSE-MIT](LICENSE-MIT)).
