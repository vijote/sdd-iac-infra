---

description: "Task list template for feature implementation"
---

# Tasks: Destroy Pipeline

**Input**: Design documents from `/specs/004-destroy-pipeline/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: The examples below include test tasks. Tests are OPTIONAL - only include them if explicitly requested in the feature specification.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Single project**: `src/`, `tests/` at repository root
- **Web app**: `backend/src/`, `frontend/src/`
- **Mobile**: `api/src/`, `ios/src/` or `android/src/`
- Paths shown below assume single project - adjust based on plan.md structure

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [ ] T001 Create GitHub Actions workflow directory structure in .github/workflows/
- [ ] T002 Create scripts directory for helper scripts in scripts/
- [ ] T003 [P] Create .github/workflows/destroy-dev-environment.yml workflow file with basic structure

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T004 Create resource inventory generation script in scripts/generate-inventory.sh
- [ ] T005 [P] Create permission validation script in scripts/validate-permissions.sh
- [ ] T006 Create destruction orchestration script in scripts/destroy-dev.sh
- [ ] T007 [P] Configure AWS CLI and jq dependencies in workflow
- [ ] T008 Setup Terraform CLI configuration in workflow
- [ ] T009 Create state backup and archival logic

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Manual Dev Environment Destruction (Priority: P1) 🎯 MVP

**Goal**: Enable developers to manually trigger complete destruction of dev environment infrastructure to eliminate costs when not actively using the project.

**Independent Test**: Can be fully tested by triggering the manual destruction pipeline and verifying all dev environment AWS resources are terminated.

### Implementation for User Story 1

- [ ] T010 [US1] Implement workflow_dispatch trigger with environment and confirmation inputs in .github/workflows/destroy-dev-environment.yml
- [ ] T011 [US1] Add input validation step to ensure only dev environment and proper confirmation in .github/workflows/destroy-dev-environment.yml
- [ ] T012 [US1] Configure AWS OIDC authentication and permissions in .github/workflows/destroy-dev-environment.yml
- [ ] T013 [US1] Implement Terraform initialization and plan generation in .github/workflows/destroy-dev-environment.yml
- [ ] T014 [US1] Add terraform destroy execution with error handling in .github/workflows/destroy-dev-environment.yml
- [ ] T015 [US1] Implement progress indicators and status reporting in .github/workflows/destroy-dev-environment.yml
- [ ] T016 [US1] Add post-destruction verification and completion confirmation in .github/workflows/destroy-dev-environment.yml
- [ ] T017 [US1] Create state backup artifact upload in .github/workflows/destroy-dev-environment.yml

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - Safety Confirmations (Priority: P1)

**Goal**: Provide confirmation prompts and dry-run capabilities to prevent accidental destruction of infrastructure.

**Independent Test**: Can be fully tested by triggering the pipeline and verifying that confirmation steps are required and can be cancelled.

### Implementation for User Story 2

- [ ] T018 [US2] Implement dry-run mode with terraform plan -destroy in .github/workflows/destroy-dev-environment.yml
- [ ] T019 [US2] Add destruction preview display in workflow summary in .github/workflows/destroy-dev-environment.yml
- [ ] T020 [US2] Implement cancellation window before actual destruction in .github/workflows/destroy-dev-environment.yml
- [ ] T021 [US2] Add explicit confirmation validation step in .github/workflows/destroy-dev-environment.yml
- [ ] T022 [US2] Create resource inventory generation before destruction in scripts/generate-inventory.sh
- [ ] T023 [US2] Add permission validation before allowing destruction in scripts/validate-permissions.sh
- [ ] T024 [US2] Implement clear warning messages and resource count display in .github/workflows/destroy-dev-environment.yml
- [ ] T025 [US2] Add cancellation handling and cleanup on abort in .github/workflows/destroy-dev-environment.yml

**Checkpoint**: At this point, User Story 2 should be fully functional and testable independently

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Final touches, error handling, reporting, and documentation

- [ ] T026 [P] Implement comprehensive error handling for partial destruction scenarios in .github/workflows/destroy-dev-environment.yml
- [ ] T027 [P] Add retry logic for failed destruction attempts in scripts/destroy-dev.sh
- [ ] T028 [P] Create detailed destruction report generation in scripts/destroy-dev.sh
- [ ] T029 [P] Implement audit logging for all destruction activities in .github/workflows/destroy-dev-environment.yml
- [ ] T030 [P] Add GitHub status updates and notifications in .github/workflows/destroy-dev-environment.yml
- [ ] T031 [P] Create pre-destruction inventory report in scripts/generate-inventory.sh
- [ ] T032 [P] Add post-destruction verification script in scripts/destroy-dev.sh
- [ ] T033 [P] Implement state archival with 90-day retention in .github/workflows/destroy-dev-environment.yml
- [ ] T034 Create comprehensive README for the destroy pipeline in .github/workflows/README.md
- [ ] T035 Add troubleshooting guide and common error solutions in docs/destroy-troubleshooting.md
- [ ] T036 Create cost verification checklist in docs/cost-verification.md
- [ ] T037 Add workflow testing and validation instructions in docs/workflow-testing.md

---

## Dependencies

### User Story Completion Order

1. **User Story 1** (Manual Dev Environment Destruction) - P1
   - Can be implemented after Phase 2 completion
   - Independent of User Story 2

2. **User Story 2** (Safety Confirmations) - P1
   - Can be implemented after Phase 2 completion
   - Independent of User Story 1
   - Enhances User Story 1 with safety features

### Critical Path

Phase 1 → Phase 2 → (User Story 1 || User Story 2) → Phase 5

### Parallel Execution Opportunities

**Within User Story 1**:
- T012, T013, T014 can be developed in parallel (different sections of workflow)
- T016, T017 can be developed in parallel (independent features)

**Within User Story 2**:
- T022, T023, T024 can be developed in parallel (different scripts)
- T026, T027, T028 can be developed in parallel (error handling features)

**In Polish Phase**:
- All tasks marked [P] can be executed in parallel
- Documentation tasks (T034-T037) can be done concurrently with implementation

---

## Implementation Strategy

### MVP Scope (First Delivery)

**Minimum Viable Product**: User Story 1 only
- Complete Phase 1 and Phase 2
- Implement all User Story 1 tasks (T010-T017)
- Basic safety features from User Story 2 (T018, T020)
- Essential error handling (T026)

This provides:
- Manual destruction capability
- Basic confirmation
- Core safety mechanisms
- Essential error handling

### Incremental Delivery

1. **Sprint 1**: Phase 1 + Phase 2 (Foundation)
2. **Sprint 2**: User Story 1 (Core destruction)
3. **Sprint 3**: User Story 2 (Enhanced safety)
4. **Sprint 4**: Polish phase (Production readiness)

### Risk Mitigation

- **High Risk**: Accidental destruction → Mitigated by User Story 2 safety features
- **Medium Risk**: Partial destruction → Mitigated by comprehensive error handling
- **Low Risk**: Performance issues → Mitigated by timeout and retry logic

---

## Testing Strategy

### Manual Testing Required

1. **User Story 1 Test**:
   - Deploy dev environment
   - Trigger destruction pipeline
   - Verify all resources are terminated
   - Check costs drop to baseline

2. **User Story 2 Test**:
   - Test with wrong confirmation (should fail)
   - Test with wrong environment (should fail)
   - Test cancellation during confirmation window
   - Verify dry-run shows correct resources

### Integration Testing

- Test with actual dev environment
- Verify OIDC authentication works
- Test state backup and recovery
- Validate error scenarios

---

## Success Metrics

- **Functional**: All acceptance scenarios pass
- **Performance**: Destruction completes within 10 minutes
- **Safety**: Zero accidental destructions
- **Audit**: All activities logged for 90 days
- **Cost**: Dev costs drop to ~$0.50/month after destruction