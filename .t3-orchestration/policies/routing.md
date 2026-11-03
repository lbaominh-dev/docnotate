# Deterministic Routing Policy

The Main Agent is the sole user-facing orchestrator. It uses this 12-step deterministic routing procedure for every incoming task.

---

## 1. Classify
Assess incoming requests across 7 dimensions:
- **Task Type**: exploration, architecture, implementation, bug fix, review, test execution, or trivial query.
- **Complexity**: Low (single file/isolated), Medium (multi-file/module), High (cross-cutting/subsystem).
- **Impact / Risk**: Low (read-only/internal), Medium (business logic), High (data migration, auth, security, external sync).
- **Scope**: Explicit file paths, directories, or modules affected.
- **Tools Needed**: read-only inspection vs file write vs shell test execution.
- **Context Size**: Small (<10KB) vs Large (broad codebase exploration).
- **Testing Needs**: Existing test suite run vs new unit tests vs integration tests.

## 2. Decide Local vs Delegated
- **Execute Locally in Main**:
  - Trivial single-step read or quick question answering.
  - Minor clarifications, formatting, or single-line typo fixes.
  - Consolidating child reports and replying to the user.
- **Delegate via `delegate_task`**:
  - Any multi-file exploration or dependency mapping (Explorer).
  - High-risk architectural decisions or design reviews (Architect).
  - Scoped coding, refactoring, or feature development (Implementer).
  - Bug diagnosis and reproduction (Debugger).
  - Code review and security checks (Reviewer).
  - Test suite execution and verification (Tester).

## 3. Select Role
- **Explorer**: Locating entry points, dependencies, constraints, or schema definitions (Read-only).
- **Architect**: System designs, technical trade-offs, architecture reviews (Read-only).
- **Implementer**: Feature implementation, refactoring, writing unit tests (Scoped writes).
- **Debugger**: Root cause analysis, defect reproduction, bug fixes (Scoped writes).
- **Reviewer**: Correctness, maintainability, AGENTS.md conformance (Read-only).
- **Tester**: Test suite execution, linter runs, evidence gathering (Test artifacts only).

## 4. Select Model Tier
- **Economy**: Routine read-only inspection, file searches, straightforward test runs.
  - *Target*: `gemini-3.8-flash-low` (`antigravity`) or `opencode/beam-free` (`opencode_2`).
- **Balanced**: Standard implementation, debugging, ordinary code review.
  - *Target*: `gemini-3.8-flash-high` (`antigravity`) or `opencode-go/deepseek-v4.1-flash` (`opencode_2`).
- **Premium**: High-risk architecture, security analysis, or escalation after repeated failures.
  - *Target*: `claude-sonnet-4-6` (`antigravity`), `claude-opus-4-6-thinking` (`antigravity`), or `opencode-go/deepseek-v4-pro` (`opencode_2`).
  - *Rule*: Long tasks do not justify Premium tier; only verified complexity and risk do.

## 5. Resolve Actual Target
- Use only confirmed available models from `.t3-orchestration/models.yaml` verified during capability audit.
- Do not guess model IDs. If a model is unavailable, fall back to a verified peer model in the same tier.

## 6. Schedule & Concurrency
- **Concurrency Cap**: At most 3 active child tasks concurrently.
- **Parallelization**: Parallelize independent read-only tasks (e.g. Explorer + Tester).
- **Serialization**: Enforce strictly 1 writer per worktree. Never run concurrent writing tasks against the same working tree.

## 7. Delegate Task
- Construct task payload complying with `.t3-orchestration/schemas/task.schema.json`.
- Invoke `delegate_task` with exact parameters:
  - `role`: matched role enum (`research`, `implementation`, `review`, `test`, `design`, `general`).
  - `mode`: `"wait"` if turn requires immediate synchronous result, `"async"` for background execution.
  - `isolation`: `"shared"` for shared checkout or `"worktree"` for isolated branch/PR.
  - `target`: `{ providerInstanceId, model }`.

## 8. Wait & Observe
- Wait for child completion natively.
- Never poll with busy loops (`task_status`, `sleep`).
- Inspect terminal status (`completed` vs `failed`).

## 9. Structured Handoff
- Main validates child output against `.t3-orchestration/schemas/result.schema.json`.
- Extract concise findings, file references, and risks.
- Pass validated findings into subsequent dependent tasks. Do not expect children to see Main's conversation history.

## 10. Verify
- Ensure changes pass required tests (via Tester child or local verification).
- Route medium/high risk changes to Reviewer.
- Fix cycle budget: At most 2 fix cycles between Implementer/Debugger and Reviewer/Tester.

## 11. Escalate
- Escalate to higher tier only when:
  - Repeated test failures after 2 fix cycles.
  - Complex concurrency, race condition, or novel architectural defect detected.
  - Always record rationale in task handoff notes.

## 12. Report
- Main produces the single consolidated final response to the user.
- Detail:
  - What was accomplished and verified.
  - Changed files with exact links.
  - Factual test results with commands run.
  - Any remaining risks or limitations.
  - Never fabricate metrics, costs, or unverified claims.
