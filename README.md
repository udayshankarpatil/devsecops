# `gitops` branch

**DO NOT** edit code in this branch by hand.  This branch is the GitOps deployment state for **task-manager** and is managed
exclusively by CI.

## What is here

`ops/helm/task-manager/values.yaml` — a copy of the Helm chart from the `dev`
branch with image tags pinned to the last merged commit SHA:

```yaml
images:
  api:
    tag: <commit-sha>
  fetch:
    tag: <commit-sha>
  ingest:
    tag: <commit-sha>
```

## How it gets updated

On every merge to dev, the CI pipeline:

1. Builds and pushes new images to GHCR tagged with the commit SHA
2. Copies the full Helm chart from dev (picking up any template changes)
3. Pins the three image tags to the new SHA
4. Commits and pushes to this branch

## How it affects the local deployment

ArgoCD watches this branch and syncs the local Kind cluster whenever it changes.

## Where to find the source code

All application code and infrastructure lives on `main` and derived branch.
