# CI/CD Pipeline

## How GitOps works

```
merge to dev
    │
    ▼
CI: security gates (SAST, SCA, secrets, IaC scan)
    │
    ▼
CI: build image on the runner → Trivy scan → push to GHCR (only if scan passes)
    │
    ▼
CI: generate SBOM artifact per image
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
| PR opened / updated against `dev` | **test** + all **security** jobs (SAST, SCA, secrets, IaC, Dockerfile lint) |
| PR merged into `dev` | all of the above → **build** (scan + push images to GHCR) → **SBOM** → **update-gitops** |

### Security gates

All security jobs run in parallel with the test matrix on every PR and push. The
`build` job will not start unless every security gate passes.

| Job | Tool | What it checks | Blocks build? |
|---|---|---|---|
| `sast` | Bandit | Python security anti-patterns in source code | Yes |
| `sca` | pip-audit | Known CVEs in Python dependencies | Yes |
| `lint-dockerfiles` | Hadolint | Dockerfile best-practice violations | Yes (errors only) |
| `secrets-scan` | Gitleaks | Hardcoded secrets anywhere in git history | Yes |
| `scan-configs` | Trivy (misconfig) | Helm / docker-compose misconfigurations | Yes (CRITICAL/HIGH) |
| `scan-images` | Trivy (image) | OS + pip CVEs in built Docker images | Yes (CRITICAL/HIGH fixed) |
| `sbom` | Syft (via anchore/sbom-action) | Generates SBOM artifact — non-blocking | No |

### Image scanning flow

Images are scanned **before** they are pushed to GHCR. A vulnerable image never
reaches the registry:

```
build image on the GitHub Actions runner (not pushed yet)
    │
    ▼
Trivy scan (exit 1 on CRITICAL/HIGH fixed CVEs)
    │  fails → job stops, image never pushed
    ▼  passes
push to GHCR
    │
    ▼
generate SBOM
```

### Suppressing a finding

**Trivy (CVE or misconfig rule):** add an entry to `ops/config/.trivyignore` at the repo root
with a justification comment and an expiry date.

**Bandit:** add `# nosec BXXX` inline with a brief comment explaining why the
finding is not exploitable in context.

**pip-audit:** add `--ignore-vuln GHSA-xxxx` to the pip-audit CI step and record
the decision in `ops/config/.trivyignore` (for traceability) or a comment in the PR.

**Hadolint:** add `# hadolint ignore=DLXXXX` above the offending `RUN` line, or
add the rule to the global `ignore` list in `ops/config/hadolint.yaml` if it applies to all
Dockerfiles.

**Gitleaks:** add a `[allowlist]` entry to `.gitleaks.toml` (create if needed).
Only use this for confirmed false positives — if the secret is real, rotate it.

### Day-to-day developer workflow

1. Branch off `dev`, make your changes, open a PR back to `dev`.
2. All test and security jobs run automatically. All must be green before merging.
3. On merge, images are scanned then pushed to GHCR tagged with the commit SHA and
   a floating `dev` tag. ArgoCD picks up the new tags automatically.

### One-time repo setup (owner only)

**1. Allow Actions to push packages**

Settings → Actions → General → Workflow permissions → **Read and write permissions**

**2. Protect the branch** (optional but recommended)

Settings → Branches → Add rule for `dev`:
- Enable **Require status checks to pass before merging**
- Add checks: `Test api`, `Test fetch`, `Test ingest`, `SAST – api`,
  `SAST – fetch`, `SAST – ingest`, `SCA – api`, `SCA – fetch`, `SCA – ingest`,
  `Lint Dockerfiles`, `Secret Scan`, `Scan IaC configs`

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

### Published SBOM artifacts

After each successful merge build, a Software Bill of Materials (SPDX format) is
attached as a GitHub Actions artifact for each service:

```
sbom-api-<sha>.spdx
sbom-fetch-<sha>.spdx
sbom-ingest-<sha>.spdx
```

Find them under **Actions → (workflow run) → Artifacts**.
