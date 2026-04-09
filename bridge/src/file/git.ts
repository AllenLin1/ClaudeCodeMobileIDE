import { execFile } from "child_process";
import { promisify } from "util";

const execFileAsync = promisify(execFile);

export interface GitStatus {
  branch: string;
  ahead: number;
  behind: number;
  files: GitFileStatus[];
}

export interface GitFileStatus {
  path: string;
  status: "M" | "A" | "D" | "R" | "?" | "U";
  staged: boolean;
}

export interface GitCommit {
  hash: string;
  shortHash: string;
  message: string;
  author: string;
  date: string;
}

async function git(
  args: string[],
  cwd: string
): Promise<string> {
  const { stdout } = await execFileAsync("git", args, {
    cwd,
    maxBuffer: 10 * 1024 * 1024,
    timeout: 10_000,
  });
  return stdout.trim();
}

export class GitService {
  async status(cwd: string): Promise<GitStatus> {
    const branchOutput = await git(
      ["rev-parse", "--abbrev-ref", "HEAD"],
      cwd
    ).catch(() => "unknown");

    let ahead = 0;
    let behind = 0;
    try {
      const revList = await git(
        ["rev-list", "--left-right", "--count", "HEAD...@{upstream}"],
        cwd
      );
      const [a, b] = revList.split("\t").map(Number);
      ahead = a || 0;
      behind = b || 0;
    } catch {
      // no upstream configured
    }

    const porcelain = await git(
      ["status", "--porcelain=v1"],
      cwd
    ).catch(() => "");

    const files: GitFileStatus[] = porcelain
      .split("\n")
      .filter(Boolean)
      .map((line) => {
        const x = line[0];
        const y = line[1];
        const filePath = line.slice(3);
        let status: GitFileStatus["status"] = "M";
        const staged = x !== " " && x !== "?";

        const indicator = staged ? x : y;
        switch (indicator) {
          case "M": status = "M"; break;
          case "A": status = "A"; break;
          case "D": status = "D"; break;
          case "R": status = "R"; break;
          case "?": status = "?"; break;
          case "U": status = "U"; break;
        }

        return { path: filePath, status, staged };
      });

    return { branch: branchOutput, ahead, behind, files };
  }

  async diff(cwd: string): Promise<string> {
    return git(["diff", "--stat", "--patch"], cwd).catch(() => "");
  }

  async log(cwd: string, limit: number = 20): Promise<GitCommit[]> {
    const format = "%H|||%h|||%s|||%an|||%aI";
    const output = await git(
      ["log", `--format=${format}`, `-${limit}`],
      cwd
    ).catch(() => "");

    return output
      .split("\n")
      .filter(Boolean)
      .map((line) => {
        const [hash, shortHash, message, author, date] = line.split("|||");
        return { hash, shortHash, message, author, date };
      });
  }
}
