/**
 * Global operation permission policy.
 *
 * - Require explicit approval for agent-issued `git push` commands.
 * - Require approval before destructive shell operations outside a Git worktree.
 * - Require approval before edit/write operations outside a Git worktree.
 * - Do not prompt for file changes confined to `/tmp` (including macOS's `/private/tmp` alias).
 * - Block other gated operations in non-interactive modes, where approval is impossible.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { dirname, isAbsolute, relative, resolve, sep } from "node:path";

const gitPushCommand = /(?:^|[;&|]\s*|&&\s*|\|\|\s*)git\s+push(?:\s|$)/m;
const destructiveCommand = /\b(rm|rmdir|unlink|shred|mkfs|dd|chmod|chown|mv)\b/i;
const tmpExemptibleCommand = /\b(rm|rmdir|unlink|shred|chmod|chown|mv)\b/i;
const approvalFreeTmpRoots = [resolve("/tmp"), resolve("/private/tmp")];

function isWithinDirectory(path: string, directory: string): boolean {
  const relativePath = relative(directory, resolve(path));
  return (
    relativePath === "" ||
    (relativePath !== ".." &&
      !relativePath.startsWith(`..${sep}`) &&
      !isAbsolute(relativePath))
  );
}

function isInApprovalFreeTmp(path: string): boolean {
  return approvalFreeTmpRoots.some((root) => isWithinDirectory(path, root));
}

/**
 * Shell parsing is intentionally conservative. Only skip approval when the command starts
 * in `/tmp` (or explicitly changes there first), uses path-oriented destructive commands,
 * and contains no path traversal, shell-expanded paths, later `cd`, or absolute path outside
 * `/tmp`. Ambiguous commands continue through the normal approval flow.
 */
function isClearlyConfinedToTmp(command: string, cwd: string): boolean {
  if (!tmpExemptibleCommand.test(command) || /\b(mkfs|dd)\b/i.test(command)) return false;
  if (command.includes("..") || /[`$~]/.test(command)) return false;

  let commandAfterInitialCd = command;
  const initialCd = command.match(
    /^\s*cd\s+(?:"([^"]+)"|'([^']+)'|([^\s;&|]+))\s*(?:&&|;)\s*/,
  );

  if (initialCd) {
    const destination = initialCd[1] ?? initialCd[2] ?? initialCd[3];
    if (!isInApprovalFreeTmp(resolve(cwd, destination))) return false;
    commandAfterInitialCd = command.slice(initialCd[0].length);
  } else if (!isInApprovalFreeTmp(cwd)) {
    return false;
  }

  if (/\bcd\b/.test(commandAfterInitialCd)) return false;

  const absolutePaths = Array.from(
    commandAfterInitialCd.matchAll(/(?:^|[\s"'=<>])(\/[^\s"';&|<>]*)/g),
    (match) => match[1],
  );
  return absolutePaths.every(isInApprovalFreeTmp);
}

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
        if (isClearlyConfinedToTmp(command, ctx.cwd)) return;

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
      const targetPath = resolve(ctx.cwd, path);
      const targetDirectory = dirname(targetPath);

      if (isInApprovalFreeTmp(targetPath)) return;

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
