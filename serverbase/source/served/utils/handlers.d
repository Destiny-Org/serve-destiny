/// Runtime table of the LSP request and notification handlers.
///
/// Each module with `@protocolMethod` / `@protocolNotification` functions
/// adds `mixin RegisterProtocolHandlers!(that.module);`. At start-up the
/// mixin registers one small function per handler, which parses the JSON
/// parameters, calls the handler and serializes its result. That code is
/// generated in the handler's own module, so the router only looks names up
/// at run time.
///
/// (Previously the router looped over every handler of every module at
/// compile time, for every call site, which needed more than 4 GB of memory
/// to compile.)
module served.utils.handlers;

import served.lsp.protocol;
import served.utils.events : protocolMethod, protocolNotification;

import std.meta : AliasSeq;
import std.range : isInputRange;
import std.traits : getUDAs, isSomeFunction, Parameters, ReturnType;

/// One `@protocolMethod` function.
struct RequestHandler
{
	enum Kind
	{
		/// returns one value: the response
		single,
		/// returns an array: results of several handlers are concatenated
		array,
		/// returns a range: each element (or chunk) is a partial result
		iterator,
	}

	string method;
	/// D name, for logs
	string name;
	Kind kind;
	/// single/array: calls the handler, returns the result as JSON
	string function(string params) call;
	/// iterator: calls the handler and passes each chunk (a JSON array)
	void function(string params, scope void delegate(string chunkJson) sink) iterate;
}

/// One `@protocolNotification` function.
struct NotificationHandler
{
	string method;
	string name;
	void function(string params) call;
}

private __gshared RequestHandler[][string] requestHandlers;
private __gshared NotificationHandler[][string] notificationHandlers;

/// Handlers registered for request `method` (empty when none).
const(RequestHandler)[] requestHandlersFor(string method)
{
	if (auto h = method in requestHandlers)
		return *h;
	return null;
}

/// Handlers registered for notification `method` (empty when none).
const(NotificationHandler)[] notificationHandlersFor(string method)
{
	if (auto h = method in notificationHandlers)
		return *h;
	return null;
}

void registerRequestHandler(RequestHandler h)
{
	requestHandlers[h.method] ~= h;
}

void registerNotificationHandler(NotificationHandler h)
{
	notificationHandlers[h.method] ~= h;
}

/// Converts the JSON parameters of a call to the handler's parameter type.
T parseParam(T)(string params)
{
	try
	{
		if (params.length && params.ptr[0] == '[')
		{
			// positional parameters: only a single argument is supported
			string got;
			params.visitJsonArray!((item) {
				if (!got.length)
					got = item;
				else
					throw new Exception("Mismatched parameter count");
			});
			return got.deserializeJson!T;
		}
		else if (params.length && params.ptr[0] == '{')
		{
			// named parameters: only structs (not D parameter names)
			return params.deserializeJson!T;
		}
		else
		{
			// no parameters: parse an empty object, or use the default
			static if (is(T == struct))
				return `{}`.deserializeJson!T;
			else
				return T.init;
		}
	}
	catch (Exception e)
	{
		ResponseError error;
		error.code = ErrorCode.invalidParams;
		error.message = "Failed converting input parameter `" ~ params
			~ "` to needed type `" ~ T.stringof ~ "`: " ~ e.msg;
		error.data = JsonValue(e.toString);
		throw new MethodException(error);
	}
}

/// Argument type of `registerProtocolHandlers` (see below).
struct RegisterToken
{
}

/// Name of the registration function the mixin below adds to module `mod`:
/// unique per module, because modules publicly import each other and one
/// shared name would be ambiguous there.
enum registerFunctionName(alias mod) = () {
	string name = "registerProtocolHandlers_";
	foreach (c; __traits(fullyQualifiedName, mod))
		name ~= c == '.' ? '_' : c;
	return name;
}();

/// Gives module `mod` a function (named `registerFunctionName!mod`) that
/// registers its public `@protocolMethod` and `@protocolNotification`
/// functions. Put it at the end of the module. The server calls these
/// functions once, before the first message
/// (`ensureProtocolHandlersRegistered`). They are plain functions, not module
/// constructors, because the modules import each other and constructors would
/// form a cycle. The dummy argument keeps code that walks a module's members
/// from treating a mention of the function as a call.
mixin template RegisterProtocolHandlers(alias mod)
{
	import served.utils.handlers : RegisterToken, registerFunctionName;

	mixin("void " ~ registerFunctionName!mod ~ q{(RegisterToken)
	{
		import served.utils.handlers : registerHandlersOf;

		registerHandlersOf!mod();
	}});
}

/// Calls the registration function of every module in `modules` once.
void ensureProtocolHandlersRegistered(modules...)()
{
	__gshared bool done;
	if (done)
		return;
	done = true;
	static foreach (mod; modules)
	{
		static assert(__traits(hasMember, mod, registerFunctionName!mod),
			"module " ~ __traits(fullyQualifiedName, mod) ~ " needs `mixin RegisterProtocolHandlers!("
			~ __traits(fullyQualifiedName, mod) ~ ");`");
		__traits(getMember, mod, registerFunctionName!mod)(RegisterToken.init);
	}
}

/// Implementation of `RegisterProtocolHandlers` (one instantiation per module).
void registerHandlersOf(alias mod)()
{
	static foreach (name; __traits(allMembers, mod))
	{{
		alias symbols = AliasSeq!(__traits(getMember, mod, name));
		static if (symbols.length == 1 && __traits(getProtection, symbols[0]) == "public"
			&& isSomeFunction!(symbols[0]))
		{
			alias fn = symbols[0];
			static foreach (uda; getUDAs!(fn, protocolMethod))
				registerRequestHandler(makeRequestHandler!fn(uda.method, name));
			static foreach (uda; getUDAs!(fn, protocolNotification))
				registerNotificationHandler(NotificationHandler(uda.method, name,
					&callNotification!fn));
		}
	}}
}

private auto invoke(alias fn)(string params)
{
	alias P = Parameters!fn;
	static if (P.length == 0)
		return fn();
	else static if (P.length == 1)
		return fn(parseParam!(P[0])(params));
	else
		static assert(0, "protocol function " ~ __traits(identifier, fn)
			~ " can't have more than one argument");
}

private void callNotification(alias fn)(string params)
{
	cast(void) invoke!fn(params);
}

private RequestHandler makeRequestHandler(alias fn)(string method, string name)
{
	alias R = ReturnType!fn;
	RequestHandler h;
	h.method = method;
	h.name = name;
	enum isArray = is(R : E[], E);
	static if (is(R : JsonValue))
	{
		h.kind = RequestHandler.Kind.single;
		h.call = &callSerialized!fn;
	}
	else static if (!isArray && isInputRange!R)
	{
		h.kind = RequestHandler.Kind.iterator;
		h.iterate = &callIterator!fn;
	}
	else
	{
		h.kind = isArray ? RequestHandler.Kind.array : RequestHandler.Kind.single;
		h.call = &callSerialized!fn;
	}
	return h;
}

private string callSerialized(alias fn)(string params)
{
	return invoke!fn(params).serializeJson;
}

private void callIterator(alias fn)(string params, scope void delegate(string) sink)
{
	foreach (chunk; invoke!fn(params))
	{
		static if (is(typeof(chunk) == T[], T))
			sink(chunk.serializeJson);
		else
			sink([chunk].serializeJson);
	}
}
