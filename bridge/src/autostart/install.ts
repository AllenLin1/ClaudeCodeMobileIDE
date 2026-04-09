import * as fs from "fs";
import * as path from "path";
import * as os from "os";

const LABEL = "com.codepilot.bridge";

function getMacOSPlist(bridgePath: string): string {
  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${bridgePath}</string>
    <string>start</string>
    <string>--daemon</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${os.homedir()}/.codepilot/bridge.log</string>
  <key>StandardErrorPath</key>
  <string>${os.homedir()}/.codepilot/bridge.error.log</string>
</dict>
</plist>`;
}

function getLinuxSystemdUnit(bridgePath: string): string {
  return `[Unit]
Description=CodePilot Bridge
After=network.target

[Service]
Type=simple
ExecStart=${bridgePath} start --daemon
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
`;
}

export function installAutostart(): void {
  const bridgePath = process.argv[1] || "codepilot-bridge";
  const platform = os.platform();

  switch (platform) {
    case "darwin": {
      const plistDir = path.join(os.homedir(), "Library", "LaunchAgents");
      const plistPath = path.join(plistDir, `${LABEL}.plist`);
      fs.mkdirSync(plistDir, { recursive: true });
      fs.writeFileSync(plistPath, getMacOSPlist(bridgePath));
      console.log(`[autostart] Installed LaunchAgent: ${plistPath}`);
      console.log(`  Load: launchctl load ${plistPath}`);
      break;
    }

    case "linux": {
      const unitDir = path.join(
        os.homedir(),
        ".config",
        "systemd",
        "user"
      );
      const unitPath = path.join(unitDir, "codepilot-bridge.service");
      fs.mkdirSync(unitDir, { recursive: true });
      fs.writeFileSync(unitPath, getLinuxSystemdUnit(bridgePath));
      console.log(`[autostart] Installed systemd user service: ${unitPath}`);
      console.log(`  Enable: systemctl --user enable codepilot-bridge`);
      console.log(`  Start:  systemctl --user start codepilot-bridge`);
      break;
    }

    case "win32": {
      const startupDir = path.join(
        os.homedir(),
        "AppData",
        "Roaming",
        "Microsoft",
        "Windows",
        "Start Menu",
        "Programs",
        "Startup"
      );
      const batPath = path.join(startupDir, "codepilot-bridge.bat");
      fs.writeFileSync(batPath, `@echo off\n"${bridgePath}" start --daemon\n`);
      console.log(`[autostart] Created startup script: ${batPath}`);
      break;
    }

    default:
      console.log(`[autostart] Unsupported platform: ${platform}`);
  }
}

export function uninstallAutostart(): void {
  const platform = os.platform();

  switch (platform) {
    case "darwin": {
      const plistPath = path.join(
        os.homedir(),
        "Library",
        "LaunchAgents",
        `${LABEL}.plist`
      );
      if (fs.existsSync(plistPath)) {
        fs.unlinkSync(plistPath);
        console.log(`[autostart] Removed: ${plistPath}`);
      }
      break;
    }
    case "linux": {
      const unitPath = path.join(
        os.homedir(),
        ".config",
        "systemd",
        "user",
        "codepilot-bridge.service"
      );
      if (fs.existsSync(unitPath)) {
        fs.unlinkSync(unitPath);
        console.log(`[autostart] Removed: ${unitPath}`);
      }
      break;
    }
    case "win32": {
      const batPath = path.join(
        os.homedir(),
        "AppData",
        "Roaming",
        "Microsoft",
        "Windows",
        "Start Menu",
        "Programs",
        "Startup",
        "codepilot-bridge.bat"
      );
      if (fs.existsSync(batPath)) {
        fs.unlinkSync(batPath);
        console.log(`[autostart] Removed: ${batPath}`);
      }
      break;
    }
  }
}
