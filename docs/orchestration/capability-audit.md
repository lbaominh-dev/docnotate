# T3 Code Nightly + Pi Native Orchestration Capability Audit

**Audit Date**: 2026-11-01  
**Harness / Client**: T3 Code Nightly (`t3 v0.1.6-nightly.20261030.3904`)  
**Pi Version**: `1.4.0`  
**Host Platform**: macOS (Darwin arm64)  
**Parent Thread**: `3c81658e-f5a7-41ce-86c2-761183cd451c`  
**Inherited Provider / Model**: `antigravity` / `gemini-3.8-flash-high`  

---

## 1. Native Orchestration Tools Discovered

Audited directly via `orchestrator_capabilities` and T3 MCP tool definitions:

| Tool | Parameters | Description / Verified Behavior |
|---|---|---|
| `orchestrator_capabilities` | `environmentId`, `search` | Enumerate active providers, models, options, and features. |
| `delegate_task` | `task`, `title`, `role`, `mode`, `isolation`, `target`, `timeoutMs`, `clientRequestId`, `runtimeMode`, `interactionMode` | Dispatches specialized child tasks across providers. Supports synchronous (`wait`) and asynchronous (`async`) execution, with shared or worktree isolation. |
| `task_status` | `taskId` | Reads status and summary of a delegated task. Returns `workState`: `working`, `waiting_for_children`, `result_available`. |
| `task_cancel` | `taskId`, `reason`, `clientRequestId` | Cancels a running delegated child task and downstream child threads. |
| `t3_worktree_status` | (none) | Inspects current git worktree, branch, and project workspace root. |
| `t3_worktree_handoff` | `branch`, `worktreePath` | Coordinates handoffs between worktrees. |

---

## 2. Provider & Model Availability

### Active & Verified Providers
1. **`antigravity`** (`canRunChildTask: true`, `canRunCrossProviderChildTask: true`)
   - **Verified Models**:
     - `gemini-3.8-flash-low` (Economy) — **Smoke test verified**
     - `gemini-3.8-flash-high` (Balanced)
     - `claude-sonnet-4-6` (Premium / Thinking)
     - `claude-opus-4-6-thinking` (Premium / Deep reasoning)
     - `gpt-oss-120b-medium` (Balanced)

2. **`opencode_2`** (OpenCode / `canRunChildTask: true`, `canRunCrossProviderChildTask: true`)
   - **Verified Models**:
     - `opencode/beam-free` (Economy) — **Cross-provider smoke test verified**
     - `opencode-go/deepseek-v4.1-flash` (Balanced)
     - `opencode-go/claude-haiku-5-5` (Balanced)
     - `opencode-go/deepseek-v4-pro` (Premium)

### Constrained / Inactive Providers
- **`codex`**: Enabled in manifest, but failed smoke test with `stream disconnected before completion: The ChatGPT user has reached their Subscription Sharing usage limit`.
- **`pi` (HDWebsoft)**: Registered in manifest, but requests for `hdwebsoft-cliproxy/*` returned `model_unavailable` due to upstream proxy mapping mismatch.
- **Disabled Providers**: `claudeAgent`, `cursor`, `grok`, `opencode` (instance 1), `fx`, `acpRegistry_omp`, `muse`.

---

## 3. Delegation Smoke Test Evidence

### Test 1: Economy Exploration Child (`antigravity` / `gemini-3.8-flash-low`)
- **Task ID**: `node:delegated-task:command:mcp:a317112c-55a2-444a-8ac7-50ef46ada5b5:delegate-task:c4b838df-bc1c-4c9c-aac1-95deb2644a7d`
- **Mode**: `wait`
- **Result**: `completed`
- **Summary**:
  ```json
  {
    "rails_version": "~> 8.1.3",
    "main_model": "Document",
    "gemfile_path": "/Users/baominh/.t3/scratch/2026-10-31-https-github-com-tortoise10h-docnotate-b9a157e7/Gemfile",
    "main_model_path": "/Users/baominh/.t3/scratch/2026-10-31-https-github-com-tortoise10h-docnotate-b9a157e7/app/models/document.rb"
  }
  ```

### Test 2: Cross-Provider Delegation (`opencode_2` / `opencode/beam-free`)
- **Task ID**: `node:delegated-task:command:mcp:a317112c-55a2-444a-8ac7-50ef46ada5b5:delegate-task:2816f7a9-e673-44db-a70e-d0a78f8411df`
- **Mode**: `wait`
- **Result**: `completed`
- **Summary**:
  ```json
  {
    "adapter": "sqlite3",
    "config_file": "config/database.yml",
    "environments": ["development", "test", "production"],
    "production_databases": ["primary", "cache", "queue", "cable"]
  }
  ```

---

## 4. Capability Audit Summary & Ground Rules

1. **Gate A Passed**: Native delegation is fully operational via `delegate_task` across at least two independent providers (`antigravity` and `opencode_2`).
2. **Worktree Support**: Supported via `isolation: "worktree"` when parallel writing tasks are needed.
3. **Lineage**: Child threads are tracked by `childThreadId` and linked via `link` URIs.
4. **Limits & Policy Enforcement**:
   - Max delegation depth (1) is enforced by prompt contract prohibiting children from calling `delegate_task`.
   - Max concurrency (3 active children) is scheduled by the Main Agent.
   - Cost budgeting is prompt-monitored.
