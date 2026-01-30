---
description: "VS Code Commit Generator: Analyzes git diff + project context to write semantic messages."
---

# Semantic Commit Message Generator (VS Code Edition)

## Goal
Analyze staged changes and synthesize a strictly formatted [Conventional Commit](https://www.conventionalcommits.org/) message.
**Crucial Upgrade:** You must correlate the code changes (What) with the active session context (Why) retrieved from the workspace.

## Phase 1: Context Retrieval (RAG)
**Execute these lookups to ground your analysis:**
1.  **Get the "What" (Code):**
    * Run: `git diff --cached` (If empty, warn user to stage files first).
2.  **Get the "Why" (Intent):**
    * **Search Workspace:** Find the most recent `SESSION_SNAPSHOT*.md` in `documentation/project-history/`.
    * **Search Workspace:** Look for `TODO` or `// RESTART NOTE` comments in the changed files themselves.
    * *Reasoning:* A commit message is better if it says "feat(auth): enable TFA per session plan" rather than just "feat(auth): update config".

## Phase 2: Change Analysis (Chain of Thought)
*Reference: `.github/knowledge/example.CoT-Prompting.md`*

Analyze the combined inputs (Diff + Session Context):
1.  **Type Determination:**
    * `feat`: New features (check against Session Snapshot "Achievements").
    * `fix`: Bug fixes (check against Session Snapshot "Blockers").
    * `chore`/`refactor`/`docs`: Maintenance/Refactoring/Documentation.
2.  **Scope Identification:** Narrow to the specific module (e.g., `core`, `auth`, `docs`).
3.  **Breaking Change Check:** Does this modify `compose.yaml` ports or volume paths? If yes, flag as `BREAKING CHANGE`.

## Phase 3: Message Synthesis
Draft the message using the **Conventional Commits** standard.

**Format Template:**
```text
<type>(<scope>): <imperative summary (max 50 chars)>

<blank line>

- <bullet point connecting change to specific file>
- <bullet point explaining the 'why' based on session context>

<optional: Footer for BREAKING CHANGE or 'Ref: #IssueID'>