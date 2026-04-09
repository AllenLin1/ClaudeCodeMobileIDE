declare module "qrcode-terminal" {
  function generate(
    text: string,
    options?: { small?: boolean },
    callback?: (code: string) => void
  ): void;
  export = { generate };
}

declare module "@anthropic-ai/claude-code" {
  export function query(options: any): AsyncIterable<any>;
}

declare module "@anthropic-ai/claude-agent-sdk" {
  export function query(options: any): AsyncIterable<any>;
}
