# Documentation index

This directory contains the production architecture, deployment, security,
operations, testing, and evidence guides for the Local AI Assistant platform.
Start with the root [project README](../README.md), then use this index to find
the authoritative guide for the task you are performing.

> **Architecture:** [Open the complete diagram catalogue](diagrams/README.md)
> · [Open the main production diagram](diagrams/production_aws_reference_architecture.png)

## Design and architecture

| Document | Purpose |
|---|---|
| [Architecture and failure domains](architecture.md) | Request paths, network tiers, HA behavior, environment differences, and immutable artifacts |
| [Architecture diagram catalogue](diagrams/README.md) | All rendered diagrams, editable Draw.io sources, and implementation links |
| [Security model](security.md) | Network, IAM, secrets, host, container, edge, and CI/CD trust controls |
| [Model lifecycle](models.md) | Digest locking, GPU-local EBS caches, rollout, rollback, and capacity constraints |
| [Cost and GPU selection](cost.md) | Cost assumptions, GPU choices, and operating-cost controls |

## Delivery and deployment

| Document | Purpose |
|---|---|
| [End-to-end deployment guide](deployment-guide.md) | Fresh-fork deployment, CI/CD controls, TLS lifecycle, promotion, rollback, and troubleshooting |
| [Terraform command reference](../terraform/README.md) | Bootstrap, environment initialization, planning, applying, and validation |
| [Packer and Ansible guide](../packer/README.md) | Immutable App/GPU AMI builds and baked configuration ownership |

## Operations and assurance

| Document | Purpose |
|---|---|
| [Operations and recovery](operations.md) | Health, alerting, diagnostics, rollback, scaling, and teardown |
| [Testing strategy](testing.md) | CI checks, deployed integration tests, database bootstrap tests, and failure exercises |
| [Production deployment evidence](evidence/production-deployment.md) | Time-bound deployment evidence, known limitations, and reproduction commands |

## Source-of-truth policy

Documentation and diagrams must change with the implementation. Terraform,
GitHub workflows, application code, and scripts remain the executable source
of truth. Historical evidence is explicitly time-bound and must not be treated
as proof that a later code change has been deployed.
