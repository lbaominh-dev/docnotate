## Project tech
- Ruby on Rails MVC
- FE with Hotwire ERB
- Database SQLite
- Background job with Solid queue backed by SQLite

## Code style
### Service logic
- We don't use service object in this project, instead all the logic will place in models layer
  - Even that all the logic may not be written directly to the Active Record model class but we may seperate them into a separate concern if possible, keep the Active Record model Line of code thin and just include related concerns for extend the logic of that model
  - There are some cases, the logic is too general or not actually belongs to any specific Active Record model, we may create a new PORO model class that just extend the behavior of Active Model for validation and place the logic here instead

### Modules / Concerns pattern
- Model-specific modules (tied to one Active Record model) are scoped under a pluralized namespace matching the model name and live in `app/models/<plural_model_name>/`
  - Example: For the `Document` model, model-specific modules go under the `Documents` namespace in `app/models/documents/`
  - Example file: `app/models/documents/markdown_parseable.rb` containing `module Documents; module MarkdownParseable; end; end`
  - This keeps related behavior colocated and clearly associated with its primary model
- Generic/reusable modules that can apply to any model are placed directly under `app/models/concerns/` with no parent module
  - Example file: `app/models/concerns/ast_parseable.rb` containing `module AstParseable; end; end`

### Controllers
- When writing Rails controller, the code style should follow the 37signals controler code style

### CSS
- Use pure CSS, with BEM naming convention, 3 kinds of css file
  1. **Foundation** — base resets, typography, body/layout defaults (e.g. `foundation.css`)
  2. **Components** — reusable UI pieces like buttons, cards, empty states (e.g. `components.css`)
  3. **Pages** — styles scoped to a specific page/screen (e.g. `pages/home.css`)
- `application.css` is the manifest: it only `@import`s the other files, no direct styles

### Rails hotwire view
- Don't make 1 large ERB file which is hard to read, if there is any duplicate, re-usuable code then split it to a partial to simplify and make the view file shorter and easier to read
- If it's a separate component in the view, should also split it into partial for simplify the main view file

## Code style
### Comment
- Only add necessary comments to code, comment should only be added to explain "why" we do that not "what"

## Testing
- The project uses Minitest as the testing framework
- Write tests only for necessary cases; avoid adding verbose or excessive tests

## Multi-Agent Orchestration (T3 Native)

### 1. Main Agent Role & Principles
- **Sole User-Facing Contact**: The Main Agent is the only agent that communicates with the user. All user conversations take place in this primary thread.
- **Local vs Delegated**: Trivial questions, simple single-line edits, and status syntheses remain local in Main. Multi-file research, complex implementation, testing, and risk-oriented reviews are delegated.
- **Max Delegation Depth = 1**: No child agent may call `delegate_task` or launch subagents.
- **Max Concurrency**: Schedule at most 3 active child tasks simultaneously.
- **Single-Writer per Checkout**: Only one writing child agent may modify a shared worktree at a time. For concurrent edits, use `isolation: "worktree"`.
- **Review & Verification**: High-risk changes require a separate Reviewer task. Code changes must include test evidence. Maximum 2 fix cycles.
- **Reporting Integrity**: Never report unverified success, invented metrics, or fabricated costs.

### 2. Specialized Roles
- **Explorer** (Economy tier): Read-only codebase exploration, mapping structure, locating entry points, gathering file evidence.
- **Architect** (Premium tier, when justified): High-level system design, evaluating trade-offs, architecture guidelines.
- **Implementer** (Balanced tier): Scoped feature implementation, refactoring, writing unit tests adhering to Rails/Hotwire rules above.
- **Debugger** (Balanced tier): Root-cause analysis, reproduction, minimal defect fixing.
- **Reviewer** (Balanced/Premium tier): Code correctness, security, architectural compliance with `AGENTS.md` conventions. Read-only.
- **Tester** (Economy/Balanced tier): Running Minitest and RuboCop, reporting factual test outcomes. Modifies test artifacts only.

### 3. Orchestration Policies & Configurations
- Detailed policies are located in `.t3-orchestration/`:
  - `config.yaml`: Orchestration configuration and concurrency limits.
  - `models.yaml`: Verified model tiering and provider mappings.
  - `policies/routing.md`: 12-step deterministic routing procedure.
  - `policies/delegation.md`: Delegation modes, worktree isolation, and cancellation rules.
  - `policies/verification.md`: Review gates, test verification, and fix cycle limits.
  - `schemas/task.schema.json` & `schemas/result.schema.json`: Structured task and result contracts.
