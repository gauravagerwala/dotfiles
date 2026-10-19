---
name: learning-retro
description: Use when the user invokes a learning retrospective, asks to review their understanding, or asks to remember, correct, or forget an understanding-memory entry. Review actual session evidence and maintain a brief memory of scoped understanding. Do not run merely because a coding task finished.
---

# Learning retro

Review what the session tells us about the user's understanding and improve the
next interaction. This extends the environment-improvement idea behind Matt
Pocock's retro with an evidence-based understanding review. It does not require
or replace that skill.

## Inputs and scope

- The user's requested session or memory correction. Default to the current
  conversation if they did not name a session.
- The selected understanding memory and profile from applicable `AGENTS.md`
  instructions or an explicit user-supplied path and profile.
- [The memory contract](references/memory-contract.md).

Read the contract before edits. Invocation authorizes routine memory updates
within the selected profile. Honor narrower requests: a request to forget one
concept is not authorization to revise unrelated entries. If the user asks for
a proposal or read-only review, do not write. Do not request confirmation for
routine authorized updates.

## Procedure

1. Read the selected memory. If a path and profile are selected but the file is
   missing, create it using the contract's empty layout. If none is selected,
   complete a conversation-only retro and show a proposed delta; ask for a path
   only if persistence is requested. Never guess another person's profile.
2. Review the actual conversation or the specific accessible session provided
   by the user. Distinguish user reasoning and user-authored work from generated
   explanations and code. Do not search unrelated histories. If the requested
   session is inaccessible, state that limitation and do not invent evidence.
3. Identify a few useful candidates: a demonstrated causal model, a specific
   confusion, a stated preference, unnecessary repetition, or a remaining gap.
   Cite a short paraphrase and a session/turn reference when available. Do not
   invent a session ID. It is valid to find no new evidence.
4. Compare candidates with existing claims. Use the contract's state rules,
   keep the narrowest supported scope, and repair overestimates. Distinguish
   exposed from self-reported and demonstrated. A correct independent prediction
   supports only the concept and context it actually tests.
5. Merge a small delta. Update matching topics, split scopes only when useful,
   remove explicitly forgotten claims, and resolve contradictions rather than
   accumulate them. Keep demonstrated subskills if confusion concerns only a
   different scope. Preserve uncertainty when the evidence cannot resolve it.
6. Keep the file within 15 concept entries, 5 preference entries, and 600 total
   whitespace-separated words. Compact wording first. Retain current gaps and
   frequently useful concepts; then remove less useful or obsolete entries.
   Report meaningful pruning. Do not add an evidence archive in this version.
7. Immediately before saving, reread the file. If it changed, recompute the delta
   against the new content. Preserve unrelated edits. Save the complete updated
   file with the agent's file-edit tool or a temporary file and atomic rename.
   A flat file has no multi-writer transaction guarantee; use one writer at a time.
8. Report what changed, what remains uncertain, and any explanation improvement
   worth carrying forward. If nothing changed, say so. Do not repeat the lesson
   simply to produce a retro report.

## Durable improvements

For repeated explanation problems, suggest a concrete change to the response
skill or routing rule. Separate user-specific understanding and preferences
from reusable skill instructions. Apply changes to skills or project guidance
only when the user's task authorizes those changes; a memory retro alone edits
the selected memory. Do not announce or generate a retro after every answer.

## Output

Persist a brief memory delta when authorized and supported by evidence. Give a
short user-facing report, for example:

> Recorded your independent explanation of event-listener cleanup; the timer
> lifecycle remains unverified. Kept your preference for short code examples.

Never frame a person as generally "beginner", "advanced", or "bad at" a subject.
The memory is a revisable aid for choosing explanations, not a grade.
