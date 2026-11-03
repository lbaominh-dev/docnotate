# Verification & Review Policy

This policy outlines how Main validates changes, manages review-fix cycles, enforces testing requirements, and ensures production readiness.

---

## 1. Principles of Verification
- **Code requires evidence**: No implementation is marked complete without executed test runs and pass/fail evidence.
- **Review for risk**: High-risk changes (core business logic, migrations, authentication, data mutations) require independent review.
- **Strict cycle limit**: A maximum of 2 review-fix or test-fix cycles are permitted per request to avoid infinite loops.
- **Reporting integrity**: Results must reflect factual output from real tools, not model assumptions or hypothetical test runs.

## 2. Verification Workflow
```text
[Main Agent]
     │
     ├─► [Implementer Child] (scoped write)
     │        │
     │        ▼ Output changed files & unit test evidence
     │
     ├─► [Tester Child] (executes test suite / linter)
     │        │
     │        ▼
     │   Pass? ──► No ──► [Implementer Fix] (Cycle 1 / 2)
     │        │
     │       Yes
     │        ▼
     ├─► [Reviewer Child] (inspects diff against AGENTS.md)
     │        │
     │        ▼
     │   Approved? ──► No ──► [Implementer Fix] (Cycle 1 / 2)
     │        │
     │       Yes
     ▼
[Main Agent Consolidated Report]
```

## 3. High-Risk vs Low-Risk Gateways
- **Low Risk (Routine Edits / Documentation)**:
  - Local verification in Main or quick Tester run.
  - Reviewer pass optional.
- **Medium Risk (Component Changes / UI Updates)**:
  - Full test execution required.
  - Reviewer checks for Hotwire/BEM CSS compliance.
- **High Risk (Data Layer / Auth / Database Migrations)**:
  - Full test suite execution required.
  - Reviewer (Premium tier if complex) checks security, race conditions, and reversibility.
  - If review fails twice, escalate to Architect or report risks to user for explicit sign-off.

## 4. Fix Cycle Discipline
1. When Reviewer requests changes or Tester finds failures:
   - Main synthesizes the findings into a structured feedback block.
   - Main dispatches a fresh `delegate_task` to the Implementer with explicit failure notes and relevant lines.
   - Fix cycle count increments by 1.
2. If cycle count reaches 2 and tests or review still fail:
   - Halt automatic fix cycles.
   - Main evaluates remaining diff and blocker.
   - Main reports the exact failure to the user with actionable next steps. Never silently bypass failed tests.
