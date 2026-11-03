# Native Multi-Agent Orchestration Operations Guide

This guide details day-to-day operations, failure recovery, task management, and reporting practices for the Main Agent in T3 Code Nightly.

---

## 1. Daily Operations Lifecycle

```text
[User Request]
       │
       ▼
1. Main Agent receives request in primary thread.
       │
       ▼
2. Classify: Is task trivial or self-contained?
       ├─► Yes ──► Execute locally in Main & respond.
       └─► No  ──► Break into structured child tasks.
                     │
                     ▼
3. Map to Role (Explorer / Architect / Implementer / Debugger / Reviewer / Tester).
4. Resolve Provider & Model Tier (Economy / Balanced / Premium) from `models.yaml`.
5. Dispatch via `delegate_task` (max 3 concurrent active child tasks).
6. Await child completion (mode: "wait" or "async").
7. Validate child output against `result.schema.json`.
8. Chain dependent child tasks if needed (e.g. Implementer -> Tester -> Reviewer).
9. Consolidate results into a single final user-facing reply.
```

---

## 2. Dispatching Tasks via `delegate_task`

When invoking `delegate_task`:
1. Use role names: `research` (for Explorer), `implementation` (for Implementer/Debugger), `review` (for Reviewer), `test` (for Tester), `design` (for Architect).
2. Set mode:
   - `mode: "wait"`: When the Main Agent requires child results in the current turn before taking the next action.
   - `mode: "async"`: When running long background verification. Main will be notified automatically upon completion.
3. Set isolation:
   - `isolation: "shared"`: Default. The child operates directly in the project workspace root. Serialized writes only.
   - `isolation: "worktree"`: Use when a task requires an independent checkout without interfering with Main's work.

---

## 3. Handling Errors and Timeouts

### Provider Quota / Subscription Exhaustion
- **Symptom**: Task fails with `ChatGPT user has reached their Subscription Sharing usage limit` or HTTP 429.
- **Remediation**: Re-route the task to the secondary verified provider (`opencode_2` or `antigravity`). Do not retry on the same exhausted provider.

### Model Unavailable
- **Symptom**: `OrchestratorMcpFailure: model_unavailable`.
- **Remediation**: Check `orchestrator_capabilities` output for verified model IDs in `.t3-orchestration/models.yaml`. Use only verified model strings.

### Task Cancellation
- **Action**: Call `task_cancel` with `taskId` and a concise `reason`.
- **Note**: Never use `t3_thread_interrupt` on delegated child tasks.

---

## 4. Managing Fix Cycles

- If `Tester` detects failures or `Reviewer` requests changes:
  1. Main synthesizes the specific failures and references the exact code lines.
  2. Main creates a new `delegate_task` for `Implementer` with the synthesized feedback.
  3. Increments fix cycle counter.
  4. If cycle counter exceeds 2, stop automated fix attempts and present remaining blockers to the user.

---

## 5. Reporting Integrity Rules

- Report only files actually modified and commands actually executed.
- Link all files and symbols using markdown links (e.g. `[Document](file:///Users/baominh/.../app/models/document.rb)`).
- Quote raw test outputs and exit codes when reporting verification results.
- Mention child threads using their exact verbatim link tag (e.g. `<t3-thread://v2/...>`).
