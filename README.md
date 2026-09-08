# EKS Kubernetes Project

📖 Want the full, beginner-friendly walkthrough of every step, command,
and decision made in this project? See
[PROJECT_GUIDE.md](./PROJECT_GUIDE.md).

## What is this project, in one sentence?

A managed Kubernetes cluster on AWS (EKS) running on Fargate — no
worker nodes to manage — verified by deploying and confirming a real
pod, then torn down the same session since this is the one project in
the portfolio with real, unavoidable hourly cost.

## Why this project exists

The final project in this series, added specifically to cover
**Kubernetes** — the container-orchestration standard that appears in
almost every remote cloud/DevOps job posting, and the natural next step
after the [ecs-docker-project](https://github.com/Ralso11/ecs-docker-project).
Unlike every other project here, EKS's control plane has a real,
unavoidable cost (~$0.10/hour) regardless of the AWS free tier — so
this project was deliberately built, verified, and destroyed within a
single working session rather than left running.

## Architecture

```
VPC (2 public subnets across 2 AZs + 1 private subnet)
        |
Internet Gateway (public) / NAT Gateway (private, for Fargate)
        |
EKS Cluster (managed control plane)
        |
Fargate Profile (namespace: default) — runs pods with no worker nodes
        |
Test pod (hello-eks, nginx image) — verified Running via kubectl
```

- **EKS** — AWS's managed Kubernetes control plane.
- **Fargate profile** — tells EKS to run pods in the `default`
  namespace without any EC2 worker nodes, same "no servers to manage"
  philosophy as the ECS project.
- **Private subnet + NAT Gateway** — EKS Fargate profiles specifically
  require private subnets (unlike ECS Fargate, which works fine with
  public ones) — a real architectural difference worth knowing.
- **Two IAM roles** — one for the cluster control plane itself, one for
  the Fargate pods, mirroring the "different identities for different
  parts of the system" pattern from earlier projects.

## Problems & fixes — quick reference

This project hit more distinct real issues than any other in the
portfolio — a genuinely good troubleshooting story:

| Problem | Why it happened | How it was fixed |
|---|---|---|
| `VpcLimitExceeded` (5 VPCs per region, AWS's default limit) | Earlier projects' leftover VPCs, several recreated by an unrelated pipeline issue (see below) | Re-ran the `destroy` workflows for the affected earlier projects to free up capacity |
| `terraform fmt -check` failed | Manually-typed tag blocks with inconsistent alignment | Recomputed exact alignment and rewrote the file |
| `iam:CreateServiceLinkedRole` / `iam:GetRole` access denied | EKS creates its own AWS-managed service-linked role behind the scenes the first time a cluster is created in an account — the deploying user needs explicit permission to trigger that | Added a scoped permission, limited to the `eks.amazonaws.com` service |
| Fargate profile name rejected: reserved `eks-` prefix | The project's name (`eks-kubernetes-project`) happened to start with a prefix AWS reserves for its own internal use | Renamed the Fargate profile to `fargate-default` |
| Fargate profile creation failed: "not a private subnet" | EKS Fargate profiles specifically require private subnets — a real requirement, not a permissions issue | Added a private subnet + NAT Gateway |
| `ec2:DescribeAddressesAttribute` access denied | Terraform reads back extra detail on the Elastic IP after creating it | Added the missing read-only permission |
| Pushing documentation to earlier, already-destroyed projects silently rebuilt their infrastructure | Pipelines ran `apply` automatically on every push to `main`, not just intentional ones | Fixed across **all seven** portfolio repos: `apply` now requires a manual trigger (`workflow_dispatch`); `plan` still runs safely on every push |

## Cost notes

This is the only project in the portfolio with a real, unavoidable
hourly cost (~$0.10/hour for the EKS control plane, plus a small NAT
Gateway cost while it existed) — not covered by any AWS free tier.
It was built, verified with a live pod, and fully destroyed within the
same session. No `destroy.yml` was left as a "just in case" convenience
here the way it was for lower-cost projects — if this project is
redeployed for a demo, destroy it again promptly afterward.

## How to reproduce this project

1. Install Git and Terraform.
2. Create a GitHub repo, clone it locally.
3. Write Terraform for a VPC with subnets across **at least two**
   availability zones (a hard EKS requirement), plus a private subnet
   and NAT Gateway (required specifically for Fargate profiles).
4. Write the EKS cluster resource, its own IAM role, a separate IAM
   role for Fargate pods, and a Fargate profile targeting a namespace.
5. Create a dedicated IAM user. Budget extra time for permissions —
   EKS has several undocumented internal checks (service-linked roles,
   attribute reads) beyond the obvious `eks:*` actions.
6. Store the keys as GitHub Secrets, set up a protected `production`
   environment with required reviewers, and make `apply` manually
   triggered rather than automatic on push.
7. Push, manually trigger `apply`, wait (cluster creation takes
   10-15 minutes), deploy a test pod via `kubectl`, verify it's Ready.
8. Destroy immediately after verifying — don't leave this one running.

## What's next (possible future additions)

- [ ] Add a managed node group as an alternative to Fargate, to
      compare the two approaches directly.
- [ ] Deploy a small real application (not just a test pod) and expose
      it via a LoadBalancer service.
- [ ] Add Helm for package-managed Kubernetes deployments.
