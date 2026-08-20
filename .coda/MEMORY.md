# MEMORY

This file stores durable learned context for the coding agent and the user.
Do not duplicate instructions already captured in `AGENTS.md`.

## Stable User Preferences

## Stable Project Preferences

## Important Decisions
- DO NOT create documentation files inside .coda/ directory - this directory is managed by the Coda agent system. All project documentation should be created in .specify/memory/ or appropriate subdirectories following established patterns.
- Provider-agnostic Terraform modules: same code works for AWS and ministack via environment-specific tfvars in src/terraform/environments/{aws,ministack}/
- src folder organized by tool: src/terraform/, src/k8s/, src/scripts/. Terraform modules under src/terraform/modules/ (one module per spec).
## Learned Facts
- Each scaffolding spec includes: overview, scope, technical design, Terraform structure, testing strategy, success criteria, dependencies, deliverables. Templates saved in .coda/docs/
## Known Gotchas
- DO NOT create documentation files inside .coda/docs/ directory - this directory is managed by the project's documentation system. All new documentation should be created in the project root or appropriate subdirectories following established patterns.
## Source-of-Truth Pointers
- Scaffolding specs: .coda/docs/SCAFFOLDING_SPEC_00{1,2,3}_*.md. Decision log: .coda/docs/SCAFFOLDING_DECISION_LOG.md. Implementation: src/terraform/modules/
## Things To Re-Validate
