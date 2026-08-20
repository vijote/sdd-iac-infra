---
name: refine-requirements
description: Build a decision log from a bare-bones idea through guided interactive questioning. Use when you have a vague one-liner like "add a new service to my cluster" and need to explore the design space, capture reasoning, and document key decisions before writing a spec. Captures what was considered, why choices were made, and how thinking evolved.
---

# Refine Requirements via Decision Log

Explore and document your design thinking through structured, iterative questioning. This skill helps you move from vague statements ("I want to add a new service to my cluster") to a **decision log** that captures the reasoning, alternatives considered, and key choices that will inform your eventual spec.

## When to Use

- You have a one-sentence idea but no spec yet
- You're unsure what questions to ask to flesh out the concept
- You want to document requirements before diving into design
- You need to identify constraints, dependencies, and success criteria early

## The Refinement Process

### Phase 1: Core Purpose & Context
Start by understanding the **why** and **where** your idea fits.

**Questions to ask:**
1. What is the main problem this solves, or what new capability does it enable?
2. Who are the primary users or stakeholders that benefit?
3. How does this fit into your existing architecture/cluster/system?
4. Why now? What triggers this requirement?
5. Have you considered alternatives? Why is this approach the right one?

### Phase 2: Scope & Boundaries
Define what is **in-scope** and what is explicitly **out-of-scope**.

**Questions to ask:**
1. What are the core responsibilities of this [service/component/feature]?
2. What should it NOT do? (Define the boundary)
3. Is this a greenfield effort or an enhancement to something existing?
4. What is the MVP (minimum viable product), and what is future/nice-to-have?
5. Are there any hard constraints on timeline, budget, or resources?

### Phase 3: Technical Requirements
Drill into the technical details.

**Questions to ask:**
1. What are the key inputs and outputs?
2. What are the performance/scale requirements? (throughput, latency, concurrent users, data volume)
3. Reliability & availability expectations? (SLA, uptime, failure recovery)
4. Security & compliance needs? (authentication, encryption, data residency, audit)
5. Dependencies on other services/systems? (integrations, APIs, shared resources)
6. Deployment environment? (cluster type, region, infrastructure constraints)

### Phase 4: Non-Functional Requirements
Capture operational, observability, and supportability needs.

**Questions to ask:**
1. How will you monitor this? (metrics, logs, alerts)
2. How will you debug issues? (tracing, instrumentation)
3. Runbook/support needs? (operational playbooks, support escalation)
4. Cost constraints or budgets?
5. Backwards compatibility or migration concerns?

### Phase 5: Success Metrics & Acceptance Criteria
Define what "done" means.

**Questions to ask:**
1. How will you measure success? (business metrics, technical metrics)
2. What does completion look like? (deliverables, validation gates)
3. Are there hard dependencies on other teams or systems?
4. What would be considered a failure?

## How to Use This Skill

1. **Start with your idea.** Something like: "I want to add a new service to my cluster."
2. **Go through each phase** above, answering the questions thoughtfully.
3. **Capture your answers** — write them down as you go.
4. **Iterate.** If an answer raises new questions, drill deeper.
5. **Synthesize.** Once all phases are answered, synthesize the answers into a structured spec.

## Example Workflow

**Initial idea:** "We need a new authentication service."

**Phase 1 answers:**
- Problem: Current auth is tightly coupled to the monolith; hard to reuse in new microservices.
- Users: Internal microservices and future partner integrations.
- Fits into: Services tier, part of platform infrastructure.
- Why now: We're splitting the monolith and can't continue with the old approach.

**Phase 2 answers:**
- Core responsibilities: Token generation, validation, refresh; user identity lookup.
- Out of scope: User management (that's identity service), audit logging (separate system), UI.
- MVP: Internal service-to-service auth; future: OAuth2/OIDC for partner integrations.
- Timeline: 8 weeks; team: 2 engineers.

**Phase 3 answers:**
- Inputs: credentials, tokens, identity claims; outputs: JWT, validation results.
- Performance: <100ms latency, support 10K req/sec, cache for 5% cache-miss rate.
- Availability: 99.9% SLA; graceful degradation on failures.
- Security: encrypted secrets, mTLS for inter-service, audit trails.
- Dependencies: DB for credential store, cache layer (Redis), identity service for user lookups.

**Phase 4 answers:**
- Monitoring: request rate, latency, error rate, token validation failures.
- Debugging: structured logs, distributed tracing.
- Runbook: how to rotate secrets, how to roll back, escalation contacts.
- Cost: <$500/month on cloud infrastructure.

**Phase 5 answers:**
- Success: internal services migrate to new auth within 6 weeks, zero unplanned auth outages.
- Completion: service deployed, monitoring active, runbook complete, team trained.
- Dependencies: identity service must be ready first.
- Failure: if latency >500ms or availability <99%, rollback plan triggered.

## Decision Log Format

As you work through the phases, capture decisions in a **Decision Log**. Each entry records:

```markdown
# Decision Log: [System/Service Name]

## D001: [Decision Title]
**Date:** YYYY-MM-DD  
**Context:** What prompted this decision?  
**Options Considered:**
- Option A: [description] — Pros: ... Cons: ...
- Option B: [description] — Pros: ... Cons: ...

**Decision:** Option A (or hybrid)  
**Rationale:** Why this choice?  
**Implications:** What does this enable or constrain downstream?  
**Alternatives Rejected:** Why did we rule out Option B?  

---

## D002: [Next Decision]
...
```

Each decision entry includes:
- **Date & title** — when was this decided, and what about?
- **Context** — the problem or question that prompted it
- **Options** — what alternatives were seriously considered?
- **Choice & reasoning** — what did you pick and why?
- **Downstream impact** — how does this constrain future decisions?
- **Rejected alternatives** — brief explanation of what didn't make the cut

This log becomes the "why" behind your eventual spec.

## Tips for Better Decision Logs

1. **Record decisions as you make them.** Don't wait until the end; capture the moment while context is fresh.
2. **Always include alternatives.** The power of a decision log is showing what was considered and rejected.
3. **Document trade-offs.** Explicitly explain why Option A won over Option B—cost? complexity? risk? future scalability?
4. **Link decisions together.** Note how D002 depends on D001 or constrains future options.
5. **Get diverse input.** Ask stakeholders and domain experts; capture their concerns in the "Options" section.
6. **Be concise but complete.** Each decision entry should be 3-5 bullet points, not a novel.
7. **Timestamp everything.** Dates matter when you review this later or onboard new team members.

## When to Stop

You're done with the decision log when:
- You've made and recorded all major design decisions
- Each decision has clear rationale and alternatives documented
- You can point to the log and explain "why we did it this way"
- The team has aligned on the key choices
- You're ready to translate these decisions into a formal spec

The decision log becomes the source of truth for the "why" before you write the "what" (the spec).
