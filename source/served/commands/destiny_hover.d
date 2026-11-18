/// Destiny: the safety of a function, shown on hover.
///
/// In Destiny a function without an attribute is `@safe`, so the most
/// important attribute is usually not written anywhere. The hover adds one
/// line saying what applies. It is read from the declaration and the file's
/// labels (not from a compiler run), so it is a hint.
module served.commands.destiny_hover;

import std.algorithm : canFind, count;
import std.regex : matchFirst, regex;
import std.string : lineSplitter, strip, stripLeft;

/// One-line note for `declaration` (as shown on hover), or null when it is
/// not a function. `before` is the source text before the declaration in
/// its own file (for `@system:` labels), or null when unknown.
string destinySafetyNote(string declaration, string before)
{
	const decl = declaration.strip;
	if (!decl.canFind("(") || decl.matchFirst(regex(`^(struct|class|interface|union|enum|alias|import)\b`)))
		return null;

	foreach (attr; ["@trusted", "@system", "@safe"])
		if (decl.matchFirst(regex(attr ~ `\b`)))
			return "Destiny: `" ~ attr ~ "` (written on the function)";

	// templates `f(T)(T x)` and `auto f()` get their safety inferred
	const isTemplate = decl.matchFirst(regex(`\w\s*\([^()]*\)\s*\(`));
	if (isTemplate || decl.matchFirst(regex(`^(auto|ref auto)\b`)))
		return "Destiny: safety inferred by the compiler (template or `auto` function)";

	if (before.length && underSystemLabel(before))
		return "Destiny: `@system` (from a `@system:` label above it)";

	return "Destiny: `@safe` (the default; nothing written)";
}

/// Whether a `@system:` label at the top level of `before` is still active
/// (no `@safe:` / `@trusted:` label after it).
private bool underSystemLabel(string before)
{
	bool system;
	foreach (line; before.lineSplitter)
	{
		const l = line.stripLeft;
		if (line.length != l.length)
			continue;   // only labels at the top level of the module
		if (l.matchFirst(regex(`^(module\s+[\w.]+\s*;\s*)?@system\s*:`)))
			system = true;
		else if (l.matchFirst(regex(`^@(safe|trusted)\s*:`)))
			system = false;
	}
	return system;
}

unittest
{
	assert(destinySafetyNote("int sum(const int[] a)", null) == "Destiny: `@safe` (the default; nothing written)");
	assert(destinySafetyNote("int third(int* p) @system", null) == "Destiny: `@system` (written on the function)");
	assert(destinySafetyNote("int twice(T)(T x)", null).canFind("inferred"));
	assert(destinySafetyNote("void bump()", "import x;\n@system:\nint c;\n").canFind("label"));
	assert(destinySafetyNote("void bump()", "@system:\n@safe:\n") == "Destiny: `@safe` (the default; nothing written)");
	assert(destinySafetyNote("struct S", null) is null);
}
