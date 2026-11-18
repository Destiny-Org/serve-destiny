/// Destiny: diagnostics from the Destiny compiler itself.
///
/// D-Scanner only checks syntax and style, and the dub linter only runs for
/// dub projects. Destiny's own errors (for example code that is not memory
/// safe under the `@safe` default) come from the compiler, so this linter
/// runs `destiny -o-` on the current text of a document, saved or not, and
/// maps the errors back to the editor.
module served.linters.destiny;

import std.algorithm : canFind, startsWith;
import std.array : appender, split;
import std.conv : to;
import std.experimental.logger : trace, warning;
import std.file : exists, mkdirRecurse, tempDir, write;
import std.path : absolutePath, baseName, buildNormalizedPath, buildPath, dirName;
import std.process : execute;
import std.regex : ctRegex, matchFirst;
import std.string : lineSplitter, strip;

import served.extension;
import served.linters.diagnosticmanager;
import served.types;

import workspaced.api;

enum DiagnosticSlot = 3;
enum DestinyDiagnosticSource = "destiny";

/// `FILE(LINE[,COL]): Error|Warning|Deprecation: MESSAGE`
private enum diagLine = ctRegex!`^(.+?)\((\d+)(?:,(\d+))?\): (Error|Warning|Deprecation): (.*)$`;
/// supplemental lines: `FILE(LINE[,COL]):        MESSAGE`
private enum supplementalLine = ctRegex!`^(.+?)\((\d+)(?:,(\d+))?\):\s{2,}(.*)$`;

/// Checks `document` with the Destiny compiler and publishes the errors.
void lint(Document document)
{
	auto d = config(document.uri).d;
	if (!d.enableLinting || !d.enableCompilerLinting)
		return;

	const path = document.uri.uriToFile;
	const text = document.rawText.idup;
	const compiler = d.dmdPath;
	const extraArgs = d.compilerArgs.dup;
	const importPaths = d.projectImportPaths.dup;

	auto result = Future!(string[]).async(() => runCompiler(compiler, path, text,
			extraArgs, importPaths)).getYield;

	createDiagnosticsFor!DiagnosticSlot(document.uri) = parseDiagnostics(result, path, document);
	updateDiagnostics(document.uri);
}

/// Clears all Destiny diagnostics.
void clear()
{
	diagnostics[DiagnosticSlot] = null;
	updateDiagnostics();
}

/// Writes the current text next to nothing else (a private temp folder, same
/// file name, so the module name stays the same) and compiles it there. The
/// document's own folder is added to the import path, so sibling modules
/// resolve as in a normal build. Returns the compiler's output lines.
private string[] runCompiler(string compiler, string path, string text,
		const string[] extraArgs, const string[] importPaths)
{
	auto dir = buildPath(tempDir, "serve-destiny");
	mkdirRecurse(dir);
	auto copy = buildPath(dir, path.baseName);
	write(copy, text);

	auto args = [compiler, "-o-", "-color=off", "-verrors=0", "-I" ~ path.dirName];
	foreach (imp; importPaths)
		args ~= "-I" ~ imp;
	args ~= extraArgs;
	args ~= headerFlags(text);
	args ~= copy;

	try
	{
		auto r = execute(args);
		trace("destiny lint: ", args, " -> ", r.status);
		// the temp copy stands for the document itself
		return r.output.lineSplitter.map!(l => l.startsWith(copy) ? path ~ l[copy.length .. $] : l).array;
	}
	catch (Exception e)
	{
		warning("could not run the Destiny compiler '", compiler, "': ", e.msg);
		return null;
	}
}

/// Extra flags a file asks for in its first lines, as in the Destiny
/// examples and test suite: `// FLAGS: -revert=safedefault`.
private string[] headerFlags(string text)
{
	string[] flags;
	size_t n;
	foreach (line; text.lineSplitter)
	{
		if (++n > 20)
			break;
		auto l = line.strip;
		if (l.startsWith("// FLAGS:"))
			flags ~= l["// FLAGS:".length .. $].strip.split;
	}
	return flags;
}

private Diagnostic[] parseDiagnostics(string[] lines, string path, ref Document document)
{
	auto ret = appender!(Diagnostic[]);
	foreach (line; lines)
	{
		if (auto m = line.matchFirst(diagLine))
		{
			Diagnostic diag;
			diag.source = DestinyDiagnosticSource;
			diag.severity = m[4] == "Error" ? DiagnosticSeverity.error
				: m[4] == "Warning" ? DiagnosticSeverity.warning : DiagnosticSeverity.information;
			diag.message = m[5];
			const inThisFile = sameFile(m[1], path);
			// errors in other modules (imports) are shown on the first line
			diag.range = inThisFile ? lineRange(document, m[2].to!uint, m[3].length ? m[3].to!uint : 0)
				: TextRange(Position(0, 0), Position(0, 0));
			if (!inThisFile)
				diag.message = m[1] ~ "(" ~ m[2] ~ "): " ~ diag.message;
			ret ~= diag;
		}
		else if (auto m = line.matchFirst(supplementalLine))
		{
			// "`x` is declared here", "`f` is @safe by default ..." belong to
			// the error before them
			if (ret.data.length)
			{
				auto prev = &ret.data[$ - 1];
				DiagnosticRelatedInformation info;
				info.location = Location(m[1].absolutePath.uriFromFile,
						TextRange(Position(m[2].to!uint - 1, 0), Position(m[2].to!uint - 1, 0)));
				info.message = m[4];
				auto related = prev.relatedInformation.isNone ? null : prev.relatedInformation.deref;
				prev.relatedInformation = related ~ info;
				prev.message ~= "\n" ~ m[4];
			}
		}
	}
	return ret.data;
}

private bool sameFile(string reported, string path)
{
	return buildNormalizedPath(reported.absolutePath) == buildNormalizedPath(path.absolutePath)
		|| reported == path.baseName;
}

/// Range from `col` (1-based; 0 = start) to the end of line `line` (1-based).
private TextRange lineRange(ref Document document, uint line, uint col)
{
	const l = line ? line - 1 : 0;
	uint endCol = col;
	size_t n;
	foreach (text; document.rawText.lineSplitter)
		if (n++ == l)
		{
			endCol = cast(uint) text.length;
			break;
		}
	const start = col ? col - 1 : 0;
	return TextRange(Position(l, start), Position(l, endCol > start ? endCol : start + 1));
}

import std.algorithm : map;
import std.array : array;
