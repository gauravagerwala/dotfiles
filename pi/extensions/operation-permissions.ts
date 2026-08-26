/**
 * Global operation permission policy.
 *
 * - Require explicit approval for agent-issued `git push` commands.
 * - Require approval before destructive shell operations outside a Git worktree.
 * - Require approval before edit/write operations outside a Git worktree.
 * - Block those operations in non-interactive modes, where approval is impossible.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { dirname, resolve } from "node:path";

const gitPushCommand = /(?:^|[;&|]\s*|&&\s*|\|\|\s*)git\s+push(?:\s|$)/m;
const destructiveCommand = /\b(rm|rmdir|unlink|shred|mkfs|dd|chmod|chown|mv)\b/i;

export default function (pi: ExtensionAPI) {
  async function isInGitRepository(directory: string): Promise<boolean> {
    try {
      const result = await pi.exec("git", ["-C", directory, "rev-parse", "--is-inside-work-tree"]);
      return result.code === 0 && result.stdout.trim() === "true";
    } catch {
      return false;
    }
  }

  async function requestApproval(ctx: ExtensionContext, title: string, detail: string) {
    // Fail closed in print/JSON mode or any environment without an approval UI.
    if (!ctx.hasUI) {
      return { block: true, reason: `${title} blocked because no approval UI is available.` };
    }

    const allowed = await ctx.ui.confirm(title, detail);
    return allowed ? undefined : { block: true, reason: `${title} denied by user.` };
  }

  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName === "bash") {
      const command = event.input.command as string;

      // Every Git push needs a separate explicit approval.
      if (gitPushCommand.test(command)) {
        return requestApproval(ctx, "Allow Git push?", command);
      }

      if (destructiveCommand.test(command)) {
        const inGitRepo = await isInGitRepository(ctx.cwd);
        // `cd` can make a command operate outside the worktree Pi started in.
        const mayChangeDirectory = /\bcd\b/.test(command);

        if (!inGitRepo || mayChangeDirectory) {
          return requestApproval(
            ctx,
            "Allow destructive operation outside a Git repository?",
            command,
          );
        }
      }

      return;
    }

    if (event.toolName === "write" || event.toolName === "edit") {
      const rawPath = event.input.path as string;
      const path = rawPath.replace(/^@/, "");
      const targetDirectory = dirname(resolve(ctx.cwd, path));

      if (!(await isInGitRepository(targetDirectory))) {
        return requestApproval(
          ctx,
          "Allow file modification outside a Git repository?",
          rawPath,
        );
      }
    }
  });
}
