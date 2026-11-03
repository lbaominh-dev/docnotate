# Delegation & Isolation Policy

This policy governs the invocation, isolation, timeout, and cancellation of delegated child tasks in T3 Code Nightly.

---

## 1. Ground Rules
- **Single User-Facing Agent**: Only the Main Agent communicates directly with the user.
- **No Nested Delegation**: Child agents are prohibited from calling `delegate_task` or defining subagents (max delegation depth = 1).
- **Concurrency Cap**: Maximum 3 active children under prompt-driven governance.
- **Single-Writer Discipline**: Only one child agent may write to a workspace checkout at any given time.

## 2. Delegation Modes
T3 native `delegate_task` supports two modes:
1. `mode: "wait"`
   - Used when the Main Agent's current turn requires the child's result before proceeding.
   - Default timeout is 10 minutes (`timeoutMs: 600000`).
   - If a question or approval is raised, the wait ends cleanly.
2. `mode: "async"`
   - Used for longer-running background tasks.
   - The host system reactively wakes the Main Agent when the child task completes (`workState: "result_available"`).
   - Polling with `task_status` in busy loops is strictly forbidden.

## 3. Workspace Isolation Strategies
1. `isolation: "shared"` (Default)
   - The child operates in the same repository checkout as Main.
   - Used for read-only exploration (`Explorer`), targeted review (`Reviewer`), or serialized single-writer edits (`Implementer`).
   - Caution: Uncommitted edits are visible in shared checkouts.
2. `isolation: "worktree"`
   - T3 prepares an isolated git worktree branched from the current parent commit.
   - Used when multiple children need to write independently (e.g., competing prototypes or separate PRs).
   - Prevents git index collisions and file conflicts.

## 4. Parameter Mapping
When invoking `delegate_task`:
```json
{
  "task": "<Full structured prompt containing Task Contract JSON>",
  "title": "<Short human-readable task title>",
  "role": "research | implementation | review | design | test | general",
  "mode": "wait | async",
  "isolation": "shared | worktree",
  "target": {
    "providerInstanceId": "<verified_id>",
    "model": "<verified_model_id>",
    "options": []
  },
  "timeoutMs": 600000,
  "clientRequestId": "<deterministic_request_uuid>"
}
```

## 5. Cancellation & Error Handling
- **Cancellation**:
  - If a delegated task becomes obsolete (e.g., user redirects priorities or a redundant parallel branch is discarded), call `task_cancel` with the `taskId` and a clear `reason`.
  - Never call `t3_thread_interrupt` on a child thread directly.
- **Failures, Token Exhaustion & Fallbacks**:
  - Inspect child task `status` (`completed` vs `failed`).
  - Read `summary` for failure reasons (e.g. `Subscription Sharing usage limit`, `rate_limit_exceeded`, `insufficient_quota`, HTTP 429).
  - When a provider runs out of tokens or hits a quota/rate limit:
    1. Identify the active role (`explorer`, `implementer`, `debugger`, `reviewer`, `tester`, `architect`).
    2. Read `.t3-orchestration/models.yaml` -> `role_mapping.<role>.fallbacks`.
    3. Automatically re-dispatch the task to the next fallback provider/model without consuming the user's retry budget.
    4. Up to `max_retry_attempts` (default: 2) across fallbacks before surfacing an escalation to the user.
  - Never fabricate success if a child fails.
