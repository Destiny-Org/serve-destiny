// Destiny for VS Code: starts serve-destiny for .dd / .ddi files.
"use strict";

const vscode = require("vscode");
const { LanguageClient } = require("vscode-languageclient/node");

let client;

/** serve-destiny's own settings live in the "d" section; fill it from ours. */
function serverSettings(section) {
  const destiny = vscode.workspace.getConfiguration("destiny");
  const own = vscode.workspace.getConfiguration(section);
  const values = {};
  for (const key of Object.keys(own)) {
    if (typeof own[key] !== "function") values[key] = own[key];
  }
  if (section === "d") {
    values.dmdPath = destiny.get("compilerPath", "destiny");
    values.dubPath = destiny.get("desPath", "des");
  }
  return values;
}

function activate(context) {
  const command = vscode.workspace.getConfiguration("destiny").get("serverPath", "serve-destiny");

  const serverOptions = { command, args: [] };
  const clientOptions = {
    documentSelector: [{ scheme: "file", language: "destiny" }],
    middleware: {
      workspace: {
        configuration: (params) =>
          params.items.map((item) => (item.section ? serverSettings(item.section) : null)),
      },
    },
  };

  client = new LanguageClient("destiny", "Destiny (serve-destiny)", serverOptions, clientOptions);
  client.start().catch((err) => {
    vscode.window.showErrorMessage(
      `Destiny: could not start serve-destiny ("${command}"). Install it and put it on your PATH, ` +
        `or set "destiny.serverPath". ${err && err.message ? err.message : err}`
    );
  });
  context.subscriptions.push({ dispose: () => client && client.stop() });
}

function deactivate() {
  return client ? client.stop() : undefined;
}

module.exports = { activate, deactivate };
