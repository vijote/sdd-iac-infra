# `docs/` — Additional Documentation

This directory contains supplementary technical documentation that supports the project but does not fit inside individual spec directories.

## Files

| File | Description |
|------|-------------|
| [`application-workloads-spec-brief.md`](application-workloads-spec-brief.md) | High-level brief describing the application workloads that will be deployed on the cluster (SPA frontend, NodeJS API, MySQL) — provides context for Specs 005 and 006 |
| [`spec-005-006-strategy.md`](spec-005-006-strategy.md) | Strategic notes on the transition from application infrastructure (Spec 005) to the deployment pipeline (Spec 006), including sequencing decisions |
| [`spec-005-constraints.md`](spec-005-constraints.md) | Detailed constraints and limitations specific to Spec 005 — documents what is explicitly out-of-scope and why |

## How These Fit In

These documents provide **cross-cutting context** that spans multiple specs. For per-spec documentation (quickstarts, plans, tasks), look in the respective `specs/<spec-name>/` directory.
