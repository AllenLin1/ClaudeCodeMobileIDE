#!/usr/bin/env node
"use strict";

const { Command } = require("commander");
const { Bridge } = require("../dist/index");
const { installAutostart, uninstallAutostart } = require("../dist/autostart/install");

const DEFAULT_SERVER = process.env.CODEPILOT_SERVER_URL || "https://codepilot-server.YOUR_ACCOUNT.workers.dev";

const program = new Command();

program
  .name("codepilot-bridge")
  .description("CodePilot Bridge — connect Claude Code to your iOS device")
  .version("1.0.0");

program
  .command("start")
  .description("Start the bridge and display pairing QR code")
  .option("-s, --server <url>", "Server URL", DEFAULT_SERVER)
  .option("-r, --room <id>", "Room ID (reuse existing)")
  .option("-d, --daemon", "Run as background daemon")
  .action(async (opts) => {
    const bridge = new Bridge({
      serverUrl: opts.server,
      roomId: opts.room,
      daemon: opts.daemon,
    });

    process.on("SIGINT", () => {
      console.log("\n[bridge] Shutting down...");
      bridge.shutdown();
      process.exit(0);
    });

    process.on("SIGTERM", () => {
      bridge.shutdown();
      process.exit(0);
    });

    await bridge.start();
  });

program
  .command("autostart")
  .description("Install autostart on system login")
  .action(() => {
    installAutostart();
  });

program
  .command("autostart-remove")
  .description("Remove autostart")
  .action(() => {
    uninstallAutostart();
  });

program.parse();
