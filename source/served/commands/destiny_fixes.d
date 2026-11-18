/// Destiny: quick fixes for the compiler's memory-safety errors.
///
/// The Destiny compiler explains how to fix code that is not memory safe
/// under the `@safe` default ("`f` is `@safe` by default. If it must do
/// this, mark it `@system`, or move the unsafe part into a small `@trusted`
/// function ..."). These code actions make those fixes one click:
///
///   - mark the function `@system`;
///   - wrap the offending line in a `@trusted` lambda (only correct when that
///     code is safe for every input, which the title says);
///   - add `scope` to a parameter that receives a local reference.
module served.commands.destiny_fixes;

import std.algorithm : canFind, countUntil, startsWith;
import std.array : join, split;
import std.regex : matchFirst, regex;
import std.string : indexOf, lineSplitter, strip, stripLeft, stripRight;

import served.types;

/// Adds the fixes that apply to `diag` (a diagnostic from the `destiny`
/// source) to `ret`.
void addDestinyQuickFixes(ref CodeAction[] ret, ref Document document, Diagnostic diag)
{
	auto lines = document.rawText.idup.lineSplitter.array;
	const errLine = diag.range.start.line;
	if (errLine >= lines.length)
		return;

	// 1. "`f` is `@safe` by default" -> mark f @system
	if (!diag.relatedInformation.isNone)
		foreach (info; diag.relatedInformation.deref)
		{
			if (!info.message.canFind("is `@safe` by default") || info.location.uri != document.uri)
				continue;
			const declLine = info.location.range.start.line;
			if (declLine >= lines.length)
				continue;
			auto m = info.message.matchFirst(regex("^`([^`]+)`"));
			auto name = m ? m[1] : "this function";
			const text = lines[declLine];
			const indent = text.length - text.stripLeft.length;
			ret ~= quickFix("Mark `" ~ name ~ "` @system (turns off the safety checks for it)",
				document, diag, Position(declLine, cast(uint) indent), Position(declLine, cast(uint) indent),
				"@system ", false);
		}

	// 2. wrap a one-statement line in a @trusted lambda
	if (diag.message.canFind("is not allowed in a `@safe` function")
		|| diag.message.canFind("cannot call `@system`"))
	{
		const text = lines[errLine];
		const stmt = text.strip;
		if (stmt.length > 1 && stmt[$ - 1] == ';' && !stmt.startsWith("return")
			&& !stmt.canFind("{") && !stmt.canFind("}"))
		{
			const indent = text.length - text.stripLeft.length;
			ret ~= quickFix("Wrap in a @trusted lambda (only if it is safe for every input)",
				document, diag, Position(errLine, cast(uint) indent),
				Position(errLine, cast(uint) text.stripRight.length),
				"() @trusted { " ~ stmt ~ " }();", false);
		}
	}

	// 3. "... to non-scope parameter `p` calling `f`" -> `scope` on f's p
	if (auto m = diag.message.matchFirst(regex("non-scope parameter `(\\w+)` calling `([\\w.]+)`")))
	{
		const param = m[1];
		auto fn = m[2].split(".")[$ - 1];
		auto decl = regex("\\b" ~ fn ~ "\\s*\\(([^)]*)\\)");
		foreach (i, text; lines)
		{
			auto d = text.matchFirst(decl);
			if (!d || text.strip.endsWith(";") && !text.canFind("{"))
				continue;   // a call, not the declaration
			// find the parameter inside the list
			const listStart = text.indexOf(d[0]) + d[0].indexOf("(") + 1;
			auto params = d[1].split(",");
			size_t offset = listStart;
			foreach (p; params)
			{
				auto words = p.strip.split;
				if (words.length >= 2 && words[$ - 1] == param && !words.canFind("scope"))
				{
					const at = offset + (p.length - p.stripLeft.length);
					ret ~= quickFix("Add `scope` to parameter `" ~ param ~ "` of `" ~ fn ~ "`",
						document, diag, Position(cast(uint) i, cast(uint) at),
						Position(cast(uint) i, cast(uint) at), "scope ", true);
					return;
				}
				offset += p.length + 1;
			}
		}
	}
}

private CodeAction quickFix(string title, ref Document document, Diagnostic diag,
	Position start, Position end, string newText, bool preferred)
{
	TextEditCollection[DocumentUri] changes;
	changes[document.uri] = [TextEdit(TextRange(start, end), newText)];
	auto action = CodeAction(title, WorkspaceEdit(changes));
	action.kind = CodeActionKind.quickfix;
	action.diagnostics = [diag];
	action.isPreferred = preferred;
	return action;
}

import std.array : array;
import std.string : endsWith;
