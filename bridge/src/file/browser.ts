import * as fs from "fs";
import * as path from "path";

export interface FileInfo {
  name: string;
  path: string;
  isDirectory: boolean;
  size: number;
  modifiedAt: number;
  gitStatus?: string;
}

export class FileBrowser {
  async list(dirPath: string): Promise<FileInfo[]> {
    const entries = await fs.promises.readdir(dirPath, {
      withFileTypes: true,
    });

    const files: FileInfo[] = [];
    for (const entry of entries) {
      if (entry.name.startsWith(".") && entry.name !== ".gitignore") continue;
      if (entry.name === "node_modules") continue;

      const fullPath = path.join(dirPath, entry.name);
      try {
        const stat = await fs.promises.stat(fullPath);
        files.push({
          name: entry.name,
          path: fullPath,
          isDirectory: entry.isDirectory(),
          size: stat.size,
          modifiedAt: stat.mtimeMs,
        });
      } catch {
        // skip inaccessible files
      }
    }

    files.sort((a, b) => {
      if (a.isDirectory !== b.isDirectory)
        return a.isDirectory ? -1 : 1;
      return a.name.localeCompare(b.name);
    });

    return files;
  }

  async read(filePath: string): Promise<{ content: string; language: string }> {
    const content = await fs.promises.readFile(filePath, "utf-8");
    const language = this.detectLanguage(filePath);
    return { content, language };
  }

  async stat(filePath: string): Promise<{
    exists: boolean;
    size: number;
    isDirectory: boolean;
    modifiedAt: number;
  }> {
    try {
      const s = await fs.promises.stat(filePath);
      return {
        exists: true,
        size: s.size,
        isDirectory: s.isDirectory(),
        modifiedAt: s.mtimeMs,
      };
    } catch {
      return { exists: false, size: 0, isDirectory: false, modifiedAt: 0 };
    }
  }

  private detectLanguage(filePath: string): string {
    const ext = path.extname(filePath).toLowerCase();
    const map: Record<string, string> = {
      ".ts": "typescript",
      ".tsx": "typescript",
      ".js": "javascript",
      ".jsx": "javascript",
      ".py": "python",
      ".rs": "rust",
      ".go": "go",
      ".java": "java",
      ".swift": "swift",
      ".kt": "kotlin",
      ".rb": "ruby",
      ".php": "php",
      ".c": "c",
      ".cpp": "cpp",
      ".h": "c",
      ".css": "css",
      ".scss": "scss",
      ".html": "html",
      ".json": "json",
      ".yaml": "yaml",
      ".yml": "yaml",
      ".md": "markdown",
      ".sql": "sql",
      ".sh": "bash",
      ".bash": "bash",
      ".toml": "toml",
      ".xml": "xml",
    };
    return map[ext] || "plaintext";
  }
}
