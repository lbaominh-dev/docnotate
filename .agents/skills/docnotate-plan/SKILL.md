---
name: docnotate-plan
description: Plan a feature/task and open the resulting plan file in DocNotate for inline review. Use whenever the user invokes /docnotate:plan, asks to "plan and annotate", "plan and review in DocNotate", or wants to plan a task and have the plan opened in the DocNotate web UI for commenting. Triggers on /docnotate:plan or any request that combines planning a feature/implementation with opening the plan in DocNotate for review.
---

# docnotate:plan

Plan the user's task as you normally would, then write the plan to a markdown file under the project's `plans/` directory, and open that file in the local DocNotate web app so the user can annotate inline comments before handing feedback back to you.

## What this skill does NOT do

This skill is **planning only**. While running it:

- **Do not modify the codebase.** No edits, no writes, no file moves outside `plans/`.
- **Do not run side-effecting commands.** No migrations, no installs, no builds, no commits, no pushes, no deploys.
- **Do not start implementing the plan in the same turn.** The whole point of this skill is to let the user review and refine the plan in DocNotate before any code changes happen.
- **Do not open non-DocNotate URLs** in the course of this skill.

Stop once the plan is written and opened in DocNotate. Wait for the user to paste their comments back before touching anything else.

## Why this exists

Planning usually happens in the agent TUI, then feedback in a separate tool forces context switching. By writing the plan to a file and popping it into DocNotate in one shot, the user can highlight and comment on the plan without leaving their flow — then paste all comments back into the TUI as a single follow-up prompt.

## Workflow

### 1. Plan

Do the planning the way you normally would for the task the user gave you:
- Explore the relevant parts of the codebase to ground the plan in reality (real file paths, existing conventions, current dependencies).
- Break the work into clear, ordered steps.
- Call out assumptions, risks, and open questions.

Keep the plan practical and specific to *this codebase* — no generic filler.

### 2. Clarify ambiguities

Review the task and your exploration. If anything is genuinely ambiguous or would meaningfully change the shape of the plan — scope boundaries, key design decisions, preferred approach among reasonable alternatives, business rules, target APIs/contracts — resolve it with the user *before* writing the plan file. Ping them all at once rather than one at a time.

Use the `question` (ask-questions) tool to surface the things worth clarifying, batched into a single tool call offering concrete options where useful. Don't pepper the user with trivial questions; only ask what would actually lead to a meaningfully different plan. Write short, clearly-worded question text and provide specific, actionable option labels (optionally with descriptions) so the user can decide fast.

Once the user answers, proceed to write the plan informed by their response. If after exploration there's nothing worth asking — or the user already gave enough detail — skip this step and go straight to writing the plan.

### 3. Write the plan to `plans/<plan_file>.md`

- The `plans/` directory is relative to the **project root** (the current working directory of the session). If it does not exist, create it (this directory itself is fine to create — it is not a codebase change).
- Pick a short, kebab-case filename derived from the task (e.g. `plans/add-jwt-auth.md`, `plans/refactor-connection-pool.md`). If the user named the file, use their name exactly.
- Write the plan as markdown. A reasonable structure:

  ```markdown
  # <Plan title>

  ## Goal
  <one or two sentences>

  ## Context
  <what you found in the codebase that informs the plan — reference real file paths>

  ## Plan
  1. <step>
  2. <step>
  ...

  ## Risks / Open questions
  - <item>
  ```

  Adapt the structure to the task — don't force it if something simpler fits.

### 4. Resolve the DocNotate base URL

DocNotate's base URL is configurable via the `DOCNOTATE_ROOT_URL` environment variable. Resolve it with a fallback to the default, and strip any trailing slash so users can set either form interchangeably:

```bash
DOCNOTATE_ROOT_URL="${DOCNOTATE_ROOT_URL:-http://localhost:3535}"
DOCNOTATE_ROOT_URL="${DOCNOTATE_ROOT_URL%/}"
```

If `DOCNOTATE_ROOT_URL` is set but empty, treat it as unset (the `:-` fallback handles this).

### 5. Open the plan in DocNotate

If DocNotate's MCP tools are available in the current agent session, call the `open_in_browser` tool with the absolute file path:

```json
open_in_browser(file_path: "<absolute_path_to_plan_file>")
```

This registers or syncs the file, launches your desktop browser directly to the document, and returns the canonical URL.

If DocNotate MCP tools are not available (e.g. older server or standalone session), fall back to opening the URL via the system `open` command (macOS) with the **absolute** path to the file you just created:

```bash
open "${DOCNOTATE_ROOT_URL}/documents/open?file_path=<absolute_path_to_plan_file>"
```

- Use the absolute path (not `~`, not relative) so the URL is unambiguous.
- If the `open` command isn't available on this platform (e.g. Linux without `xdg-open`, Windows), use the platform equivalent (`xdg-open`, `start`) and tell the user what you ran.
- DocNotate must already be running at the resolved `DOCNOTATE_ROOT_URL`. If the command fails or the URL doesn't respond, tell the user to start DocNotate (and check the `DOCNOTATE_ROOT_URL` they set) and re-run the open command — don't silently swallow the error.

### 6. Tell the user what to do next

Briefly tell the user:
- Where the plan file lives (absolute path).
- That DocNotate should now be open with the plan loaded.
- That when they're done commenting, they can use DocNotate's copy button and paste the comments back here as their next message, and you'll revise the plan from there.
- That the plan is still a proposal — no code changes will be made until they explicitly approve it.

Keep it short — no need to re-summarize the plan itself, it's already in the file they're looking at.

## Notes

- Don't commit the plan file unless the user asks. The `plans/` directory may be gitignored or kept on purpose; respect whichever.
- If an existing plan file exists with the same name, overwrite it only if the new task is clearly a revision of the same thing. Otherwise pick a distinct filename to avoid losing prior plans.
- This skill is paired with DocNotate running locally. The base URL defaults to `http://localhost:3535` and can be overridden by setting `DOCNOTATE_ROOT_URL` (e.g. `DOCNOTATE_ROOT_URL=http://localhost:4000`). The plan file is plain markdown — the user can still open and read it even if DocNotate isn't running, they just lose the inline-commenting workflow.
- The plan is a proposal until the user explicitly approves it. After they paste comments back, revise the plan or ask follow-up questions as needed; do not start implementation until they say so.
