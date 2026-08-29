---

description: "Task list for feature implementation"
---

# Tasks: S3 State Unlock

**Input**: Design documents from `/specs/009-s3-state-unlock/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Manual testing through GitHub Actions UI (no automated tests required)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **GitHub Workflows**: `.github/workflows/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [X] T001 Create .github/workflows directory if it doesn't exist
- [X] T002 Verify AWS CLI is available in GitHub Actions runners

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T003 Document required AWS IAM permissions for the workflow
- [X] T004 Create workflow structure with proper GitHub Actions syntax

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Emergency State Unlock (Priority: P1) 🎯 MVP

**Goal**: Provide a GitHub Actions workflow that removes S3 state locks when Terraform workflows are cancelled

**Independent Test**: Run a workflow, cancel it mid-execution, then run the unlock workflow and verify a new workflow can successfully acquire the state lock

### Implementation for User Story 1

- [X] T005 [US1] Create workflow file with workflow_dispatch trigger in .github/workflows/unlock-terraform-state.yml
- [X] T006 [US1] Add bucket and state_key input parameters to workflow
- [X] T007 [US1] Configure AWS credentials setup from GitHub secrets
- [X] T008 [US1] Implement lock existence check using aws s3api head-object
- [X] T009 [US1] Implement lock removal using aws s3api delete-object
- [X] T010 [US1] Add conditional logic to handle "no lock found" scenario
- [X] T011 [US1] Add error handling for AWS authentication failures
- [X] T012 [US1] Add error handling for insufficient permissions
- [X] T013 [US1] Add error handling for bucket not found
- [X] T014 [US1] Implement workflow outputs for result and lock_found status
- [X] T015 [US1] Add GitHub Actions summary with clear success/failure messages
- [X] T016 [US1] Add job timeout to ensure workflow completes within 30 seconds

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [X] T017 [P] Add inline comments explaining each AWS CLI command
- [X] T018 [P] Validate workflow syntax using GitHub Actions validator
- [X] T019 Run quickstart.md validation scenarios
- [X] T020 [P] Update repository README with workflow usage instructions

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories

### Within Each User Story

- Core implementation before integration
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel
- All Foundational tasks marked [P] can run in parallel (within Phase 2)
- Once Foundational phase completes, all user stories can start in parallel (if team capacity allows)
- Different user stories can be worked on in parallel by different team members

---

## Parallel Example: User Story 1

```bash
# Sequential dependencies (must run in order):
T005 → T006 → T007 → T008 → T009 → T010 → T011 → T012 → T013 → T014 → T015 → T016

# Parallel tasks (can run simultaneously):
T017, T018, T020 (after user story completion)
```

---

## Implementation Strategy

### MVP Scope (User Story 1 only)
- Implement the core unlock workflow with manual trigger
- Handle basic success and failure scenarios
- Provide clear feedback to users

### Incremental Delivery
1. **First**: Basic workflow structure and trigger
2. **Second**: AWS CLI commands for lock manipulation
3. **Third**: Error handling and edge cases
4. **Fourth**: User experience improvements (summaries, outputs)

### Success Criteria
- Workflow can be manually triggered
- Successfully removes stale S3 state locks
- Handles "no lock found" gracefully
- Provides clear error messages for failures
- Completes within 30 seconds