---

description: "Task list for Application Deployment Infrastructure implementation"
---

# Tasks: Application Deployment Infrastructure

**Input**: Design documents from `/specs/005-application-deployment/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Manual validation only (per constitution - no automated testing)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Infrastructure**: `src/terraform/` for Terraform modules
- **Kubernetes manifests**: `src/terraform/modules/application-deployment/kubernetes/`
- **Scripts**: `scripts/` for deployment and validation scripts

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [X] T001 Create Terraform module structure in src/terraform/modules/application-deployment/
- [X] T002 Create environment directories in src/terraform/environments/ (dev, prod)
- [X] T003 [P] Create deployment scripts in scripts/ (deploy.sh, validate.sh, cleanup.sh)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 Create main Terraform module in src/terraform/modules/application-deployment/main.tf
- [X] T005 Create variables file in src/terraform/modules/application-deployment/variables.tf
- [X] T006 Create outputs file in src/terraform/modules/application-deployment/outputs.tf
- [X] T007 Create namespace manifest in src/terraform/modules/application-deployment/kubernetes/namespace.yaml
- [X] T008 [P] Create dev environment tfvars in src/terraform/environments/dev/terraform.tfvars
- [X] T009 [P] Create prod environment tfvars in src/terraform/environments/prod/terraform.tfvars

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Deploy Demo Applications (Priority: P1) 🎯 MVP

**Goal**: Deploy three demo applications (SPA frontend, NodeJS backend, MySQL database) on Kubernetes cluster

**Independent Test**: Deploy all three applications and verify they work together (SPA serves frontend, NodeJS serves API, MySQL stores data)

### Implementation for User Story 1

- [X] T010 [US1] Create MySQL deployment manifest in src/terraform/modules/application-deployment/kubernetes/deployments/mysql.yaml
- [X] T011 [US1] Create MySQL service manifest in src/terraform/modules/application-deployment/kubernetes/services/mysql-service.yaml
- [X] T012 [US1] Create MySQL PVC manifest in src/terraform/modules/application-deployment/kubernetes/storage/mysql-pvc.yaml
- [X] T013 [US1] Create MySQL ConfigMap in src/terraform/modules/application-deployment/kubernetes/configmaps/mysql-config.yaml
- [X] T014 [US1] Create MySQL Secret template in src/terraform/modules/application-deployment/kubernetes/secrets/mysql-secrets.yaml
- [X] T015 [P] [US1] Create NodeJS deployment manifest in src/terraform/modules/application-deployment/kubernetes/deployments/backend.yaml
- [X] T016 [P] [US1] Create NodeJS service manifest in src/terraform/modules/application-deployment/kubernetes/services/backend-service.yaml
- [X] T017 [P] [US1] Create NodeJS ConfigMap in src/terraform/modules/application-deployment/kubernetes/configmaps/backend-config.yaml
- [X] T018 [P] [US1] Create NodeJS Secret template in src/terraform/modules/application-deployment/kubernetes/secrets/backend-secrets.yaml
- [X] T019 [P] [US1] Create SPA deployment manifest in src/terraform/modules/application-deployment/kubernetes/deployments/frontend.yaml
- [X] T020 [P] [US1] Create SPA service manifest in src/terraform/modules/application-deployment/kubernetes/services/frontend-service.yaml
- [X] T021 [US1] Update main.tf to include all Kubernetes resources
- [X] T022 [US1] Add resource configuration to variables.tf
- [X] T023 [US1] Add output values to outputs.tf for service endpoints

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - Application Configuration Management (Priority: P1)

**Goal**: Manage application configurations via ConfigMaps and Secrets, separating configuration from code

**Independent Test**: Update ConfigMaps and verify applications pick up new configurations; use Secrets for sensitive data

### Implementation for User Story 2

- [ ] T024 [US2] Configure External Secrets operator in Terraform (AWS Secrets Manager integration)
- [ ] T025 [US2] Create SecretStore manifest in src/terraform/modules/application-deployment/kubernetes/secrets/secretstore.yaml
- [ ] T026 [US2] Create ExternalSecret for database credentials in src/terraform/modules/application-deployment/kubernetes/secrets/db-credentials-external.yaml
- [ ] T027 [P] [US2] Update backend deployment to use ExternalSecrets in src/terraform/modules/application-deployment/kubernetes/deployments/backend.yaml
- [ ] T028 [P] [US2] Update MySQL deployment to use ExternalSecrets in src/terraform/modules/application-deployment/kubernetes/deployments/mysql.yaml
- [ ] T029 [US2] Add environment variable injection to backend deployment
- [ ] T030 [US2] Add volume mounts for configuration files where needed

**Checkpoint**: At this point, User Story 2 should be fully functional and testable independently

---

## Phase 5: User Story 3 - Application Health Monitoring (Priority: P2)

**Goal**: Implement health checks and readiness probes for all applications

**Independent Test**: Check pod status and verify failed pods are restarted; verify readiness probes prevent traffic to unready pods

### Implementation for User Story 3

- [ ] T031 [US3] Add liveness and readiness probes to MySQL deployment in src/terraform/modules/application-deployment/kubernetes/deployments/mysql.yaml
- [ ] T032 [P] [US3] Add liveness and readiness probes to backend deployment in src/terraform/modules/application-deployment/kubernetes/deployments/backend.yaml
- [ ] T033 [P] [US3] Add liveness and readiness probes to frontend deployment in src/terraform/modules/application-deployment/kubernetes/deployments/frontend.yaml
- [ ] T034 [US3] Create health check endpoints documentation in quickstart.md

**Checkpoint**: At this point, User Story 3 should be fully functional and testable independently

---

## Phase 6: Ingress Integration

**Purpose**: Configure ingress routing for external access

- [ ] T035 Create Ingress manifest in src/terraform/modules/application-deployment/kubernetes/ingress/main-ingress.yaml
- [ ] T036 Configure path-based routing (/api/* to backend, /* to frontend)
- [ ] T037 Update main.tf to include Ingress resource

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final touches and documentation

- [ ] T038 [P] Add resource limits validation in Terraform
- [ ] T039 [P] Add security group rules for inter-service communication
- [ ] T040 Update quickstart.md with actual deployment commands
- [ ] T041 [P] Add troubleshooting section to quickstart.md
- [ ] T042 Create README for the module in src/terraform/modules/application-deployment/README.md

---

## Dependencies

### User Story Completion Order

1. **Phase 2 (Foundational)** MUST complete first
2. **User Story 1** (P1) - Core deployment
3. **User Story 2** (P1) - Configuration management
4. **User Story 3** (P2) - Health monitoring
5. **Phase 6** (Ingress) - External access
6. **Phase 7** (Polish) - Documentation and validation

### Parallel Execution Opportunities

**Within User Story 1** (after T014 completes):
- T015, T019 can run in parallel (different deployments)
- T016, T020 can run in parallel (different services)
- T017, T018 can run in parallel (different ConfigMaps/Secrets)

**Within User Story 2**:
- T027, T028 can run in parallel (different deployments)

**Within User Story 3**:
- T032, T033 can run in parallel (different deployments)

**Within Phase 7**:
- T038, T039, T041 can run in parallel

## Implementation Strategy

### MVP Scope (User Story 1 only)
Deploy the three applications with basic configuration to demonstrate a working stack. This provides immediate value and validates the core infrastructure.

### Incremental Delivery
1. **First increment**: US1 - Basic deployment
2. **Second increment**: US2 - Add proper configuration management
3. **Third increment**: US3 + Ingress - Add health monitoring and external access
4. **Final increment**: Polish and documentation

### Validation Approach
Per constitution, all validation is manual:
- Deploy using Terraform
- Verify with kubectl commands
- Test application endpoints
- Check health probe status
- Validate configuration updates

## Total Task Count

- **Phase 1**: 3 tasks
- **Phase 2**: 6 tasks
- **User Story 1**: 14 tasks
- **User Story 2**: 7 tasks
- **User Story 3**: 4 tasks
- **Phase 6**: 3 tasks
- **Phase 7**: 5 tasks

**Total**: 42 tasks

**MVP (User Story 1)**: 23 tasks (including setup and foundational)