#!/usr/bin/env python3
"""Smoke test for serve-destiny, acting like an editor over LSP (stdio).

1. open a file that is not memory safe -> expect a `destiny` error
2. change it to safe code (unsaved)   -> expect the error to disappear
3. ask for completions after `std.stdio.` -> expect `writeln`

Usage: destiny_smoke.py SERVER FILE.d   (e.g. test/data/destiny_smoke.d)
"""
import json, os, subprocess, sys, time

server, path = sys.argv[1], os.path.abspath(sys.argv[2])
uri = "file://" + path
text = open(path).read()

p = subprocess.Popen([server], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                     stderr=subprocess.DEVNULL)
msg_id = 0

def send(method, params, notify=False):
    global msg_id
    m = {"jsonrpc": "2.0", "method": method, "params": params}
    if not notify:
        msg_id += 1
        m["id"] = msg_id
    body = json.dumps(m).encode()
    p.stdin.write(b"Content-Length: %d\r\n\r\n" % len(body) + body)
    p.stdin.flush()
    return msg_id

def read():
    length = 0
    while True:
        line = p.stdout.readline()
        if not line:
            raise SystemExit("server exited")
        if line.startswith(b"Content-Length:"):
            length = int(line.split(b":")[1])
        elif line in (b"\r\n", b"\n"):
            break
    return json.loads(p.stdout.read(length))

def wait(pred, timeout=60):
    end = time.time() + timeout
    while time.time() < end:
        m = read()
        if m.get("method") in ("window/workDoneProgress/create", "client/registerCapability", "workspace/configuration"):
            if "id" in m:   # answer server requests so it does not wait
                result = [{}] * len(m["params"].get("items", [])) if m["method"] == "workspace/configuration" else None
                body = json.dumps({"jsonrpc": "2.0", "id": m["id"], "result": result}).encode()
                p.stdin.write(b"Content-Length: %d\r\n\r\n" % len(body) + body); p.stdin.flush()
            continue
        if pred(m):
            return m
    raise SystemExit("timed out")

def destiny_diags(m):
    return (m.get("method") == "textDocument/publishDiagnostics"
            and m["params"]["uri"] == uri
            and [d for d in m["params"]["diagnostics"] if d.get("source") == "destiny"])

ok = True
rid = send("initialize", {"processId": os.getpid(), "rootUri": "file://" + os.path.dirname(path),
                          "capabilities": {}, "initializationOptions": {}})
wait(lambda m: m.get("id") == rid)
send("initialized", {}, notify=True)
send("textDocument/didOpen", {"textDocument": {"uri": uri, "languageId": "d", "version": 1, "text": text}}, notify=True)
send("textDocument/didChange", {"textDocument": {"uri": uri, "version": 2},
                                "contentChanges": [{"text": text}]}, notify=True)

m = wait(destiny_diags)
for d in destiny_diags(m):
    print("1. error at line %d: %s" % (d["range"]["start"]["line"] + 1, d["message"].splitlines()[0]))

# 2. the unsafe line fixed in the editor, not saved
fixed = text.replace("return *(p + 2);", "return p[0 .. 3][2];")
send("textDocument/didChange", {"textDocument": {"uri": uri, "version": 3},
                                "contentChanges": [{"text": fixed}]}, notify=True)
m = wait(lambda m: m.get("method") == "textDocument/publishDiagnostics" and m["params"]["uri"] == uri
         and not destiny_diags(m))
print("2. after the fix: no destiny errors")

# 3. completion
probe = fixed + "\nvoid probe() { import std.stdio; std.stdio.wri }\n"
send("textDocument/didChange", {"textDocument": {"uri": uri, "version": 4},
                                "contentChanges": [{"text": probe}]}, notify=True)
lines = probe.splitlines()
line = len(lines) - 1
col = lines[line].index("wri") + 3
rid = send("textDocument/completion", {"textDocument": {"uri": uri}, "position": {"line": line, "character": col}})
m = wait(lambda m: m.get("id") == rid, timeout=120)
items = m.get("result") or []
items = items.get("items", []) if isinstance(items, dict) else items
labels = sorted({i["label"] for i in items})
print("3. completions:", ", ".join(l for l in labels if l.startswith("wri")) or "(none)")
ok = any(l.startswith("writeln") for l in labels)

p.kill()
sys.exit(0 if ok else 1)
