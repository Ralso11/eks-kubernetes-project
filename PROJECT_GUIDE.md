# The Complete Guide to This Project
### (Written so anyone, even with zero background, can understand it)

This is the final project in a portfolio series. It assumes the basics
from earlier guides (Git, GitHub, Terraform, CI/CD, containers from the
ECS project) are already familiar. This one covers **Kubernetes on
AWS** — and honestly, it hit more real problems than any other project
here, which makes it the best troubleshooting story in the whole
portfolio.

---

## Part 1 — What is Kubernetes, and why does it matter so much?

Kubernetes is a system for running and managing containers at scale.
The key difference from ECS (the previous project): **Kubernetes is an
open standard**, not something AWS invented. The exact same Kubernetes
knowledge works on AWS, Google Cloud, Azure, or a self-hosted setup
(like the k3s cluster already in an earlier homelab project) — which is
exactly why "Kubernetes" shows up in so many job postings, regardless
of which cloud a company uses.

**EKS (Elastic Kubernetes Service)** is AWS's *managed* version — AWS
runs the Kubernetes "control plane" (the brain that decides what runs
where) for you.

## Part 2 — An important, real cost difference

Every previous project in this portfolio was free or nearly free to
leave running. **EKS is different: the control plane costs money the
entire time it exists**, around $0.10/hour, regardless of how much or
little it's actually used, and this isn't covered by any AWS free tier.
This is why this project was built, verified, and destroyed within a
single session — leaving it running "just in case" would have been a
real, ongoing expense for no benefit.

## Part 3 — Why EKS specifically needs two availability zones

Unlike the earlier VPC project (where one subnet was enough), EKS
**requires** subnets spread across at least two availability zones,
even for a tiny test cluster. This is a genuine AWS platform
requirement, not a style choice — it reflects how real Kubernetes
clusters are built to survive one data center having a problem, and AWS
enforces the pattern even at the smallest scale.

## Part 4 — Fargate for EKS: same idea, new requirement

Like the ECS project, this one uses **Fargate** — no EC2 worker nodes to
size or manage, AWS runs the containers directly. But a real difference
emerged during this project: **EKS Fargate profiles specifically
require private subnets** — subnets with no direct route to the
internet. ECS Fargate, by contrast, worked fine with public subnets in
the earlier project. This isn't a bug or a permissions issue; it's how
EKS Fargate is actually designed to work, and only became apparent by
hitting the actual error:

```
InvalidParameterException: Subnet ... provided in Fargate Profile
is not a private subnet
```

**The fix required real new infrastructure**, not just a permission
tweak:
- A **private subnet** (no route to an Internet Gateway)
- A **NAT Gateway** — this is what lets resources in a private subnet
  still reach the internet (e.g., to pull container images) while
  staying unreachable *from* the internet directly
- A **route table** sending the private subnet's outbound traffic
  through the NAT Gateway instead of an Internet Gateway

## Part 5 — The IAM permissions saga (the richest part of this project)

This project needed more rounds of IAM troubleshooting than any other
in the portfolio. Worth walking through each one, because they're all
genuinely different *kinds* of gaps:

**1. `iam:CreateServiceLinkedRole` / `iam:GetRole` denied on cluster
creation.** The first time EKS is used in an AWS account, it needs to
create its own special AWS-managed role (a "service-linked role")
behind the scenes. The deploying user needs explicit permission to
trigger that one-time setup — an easy thing to miss since it's not an
action *your* Terraform code calls directly.

**2. The same error again, for Fargate specifically.** Fargate has its
*own* separate service-linked role need
(`AWSServiceRoleForAmazonEKSForFargate`), distinct from the cluster's.
Two different AWS sub-services, two separate one-time permission checks.

**3. `ec2:DescribeAddressesAttribute` denied.** After creating the
Elastic IP (needed for the NAT Gateway), Terraform tries to read back
extra detail about it — a routine "did this actually work correctly"
check that needed its own read permission.

**The pattern worth remembering:** EKS performs many more of these
"routine internal check" API calls than services like Lambda or ECS —
confirmed by checking current best practices before troubleshooting
further, rather than guessing indefinitely. When a service is known to
be permission-hungry like this, budgeting extra iteration time (and
being ready to broaden narrowly-scoped statements when exact resource
ARNs don't match cleanly) is the realistic approach, not a sign
anything was done wrong.

## Part 6 — The reserved name prefix

A smaller, easier lesson: the Fargate profile's name was set to
`${var.project_name}-default`, which evaluated to
`eks-kubernetes-project-default` — and AWS rejected it because it
starts with `eks-`, a prefix AWS reserves for its own internal use.
**Any AWS resource name can potentially collide with a reserved
prefix** — worth remembering as a category of error, not just fixing
this one instance.

## Part 7 — The big lesson: pushing code isn't always harmless

While troubleshooting this project, a completely unrelated discovery
turned out to be the most valuable lesson of the whole portfolio:
checking the AWS Console revealed **leftover infrastructure from
already-destroyed earlier projects** (`ecs-docker-project`,
`vpc-networking-project`). Investigating why revealed the real cause:
every pipeline's `apply` job was configured to run automatically on
**every push to `main`** — including harmless documentation commits
pushed *after* those projects had already been intentionally destroyed.
Each doc push silently rebuilt the infrastructure from scratch.

**The fix, applied across all seven repos in the portfolio:** changed
every `apply` job's trigger so it only runs when manually started
(`workflow_dispatch`), while `plan` (which only *previews* changes,
never touches real infrastructure) still runs automatically on every
push, exactly as before. This means:

```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:      # new: enables the manual "Run workflow" button

jobs:
  apply:
    if: github.event_name == 'workflow_dispatch'   # changed: only manual runs
```

**Why this matters beyond just this portfolio:** this is a genuinely
common real-world CI/CD mistake, and catching + fixing it — across an
entire set of projects, not just patching the one that revealed it — is
exactly the kind of systemic thinking that separates "I can write a
pipeline" from "I understand what a pipeline actually does over time."

## Part 8 — Command/concept glossary (new items vs previous projects)

| Term | Plain-language meaning |
|---|---|
| Control plane | The "brain" of a Kubernetes cluster, managing what runs where — AWS manages this for you in EKS |
| Fargate profile | Tells EKS to run pods in a given namespace without any EC2 worker nodes |
| Service-linked role | A special AWS-managed IAM role that a service creates for itself the first time it's used in an account |
| NAT Gateway | Lets resources in a private subnet reach the internet outbound, without being reachable from the internet inbound |
| `workflow_dispatch` | A GitHub Actions trigger enabling a manual "Run workflow" button, as opposed to running automatically |
| Reserved prefix | A naming pattern (like `eks-`) that AWS reserves for its own internal resources, rejected if used elsewhere |

## Part 9 — How to explain this project in an interview

> "I deployed a managed Kubernetes cluster on AWS using EKS with
> Fargate, so there are no worker nodes for me to manage directly. This
> was the most permission-hungry service I've worked with — I hit and
> resolved several distinct IAM gaps, including AWS's own internal
> service-linked role requirements, and I learned that EKS Fargate
> specifically requires private subnets with a NAT Gateway, unlike ECS
> Fargate. Because EKS has a real hourly cost with no free tier, I
> built, verified with a live pod, and destroyed it within one session.
> Troubleshooting this also surfaced a real gap across my whole
> portfolio — my pipelines were re-running deployments on every push,
> even documentation-only ones — so I fixed that architecturally across
> all seven of my projects, not just this one."

That story demonstrates depth (real, varied troubleshooting), judgment
(cost-awareness), and systemic thinking (fixing the root cause
everywhere it applied, not just patching the symptom) — exactly what
distinguishes a strong portfolio project from a simple tutorial replay.

---

*This document, together with the repo's README.md, covers everything
needed to fully understand, explain, and rebuild this project.*
