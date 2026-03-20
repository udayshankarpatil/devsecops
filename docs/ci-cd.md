# CI/CD Pipeline

## How GitOps works

```
merge to dev
    │
    ▼
CI: build + push images to GHCR
    │
    ▼
CI: commit updated SHA tags to gitops branch (ops/helm/task-manager/values.yaml)
    │
    ▼
ArgoCD: detects gitops change, syncs Kind cluster
    │
    ▼
Kind: rolls out new pods
```

ArgoCD watches the `gitops` branch, not `dev`. The `gitops` branch is written only
by CI and is never edited by hand.

## CI Pipeline

The workflow lives in `.github/workflows/ci.yml`:

| Event | Jobs that run |
|---|---|
| PR opened / updated against `dev` | **test** (all three services) |
| PR merged into `dev` | **test** → **build** (push images to GHCR) → **update-gitops** (pin SHA in ops/helm/values.yaml) |

### Day-to-day developer workflow

1. Branch off `dev`, make your changes, open a PR back to `dev`.
2. The three test jobs run automatically. All must be green before the PR can be merged.
3. On merge, production images are built and pushed to GHCR tagged with the commit SHA and a floating `dev` tag.

### One-time repo setup (owner only)

**1. Allow Actions to push packages**

Settings → Actions → General → Workflow permissions → **Read and write permissions**

**2. Protect the branch** (optional but recommended)

Settings → Branches → Add rule for `dev`:
- Enable **Require status checks to pass before merging**
- Add checks: `Test api`, `Test fetch`, `Test ingest`

**3. Make GHCR images public** (after the first merge triggers a build)

Navigate to `github.com/<you>?tab=packages`, open each package, set visibility to
**Public**. This avoids needing pull credentials in Kubernetes.

### Published images

```
ghcr.io/<owner>/task-manager/api:<commit-sha>     # immutable — pinned by gitops branch
ghcr.io/<owner>/task-manager/api:dev              # floating — latest merged build
ghcr.io/<owner>/task-manager/fetch:<commit-sha>
ghcr.io/<owner>/task-manager/fetch:dev
ghcr.io/<owner>/task-manager/ingest:<commit-sha>
ghcr.io/<owner>/task-manager/ingest:dev
```
