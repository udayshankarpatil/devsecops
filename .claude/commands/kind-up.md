Bootstrap the local Kind cluster for task-manager.

Run from the repo root (host machine — not inside the devcontainer):

```bash
ansible-playbook ansible/kind-up.yml
```

If the image owner hasn't been set in values.yaml yet, pass it explicitly:
```bash
ansible-playbook ansible/kind-up.yml -e image_owner=<github-username>
```

The playbook is idempotent — safe to run again after a partial failure. It will:
1. Create the Kind cluster (if absent)
2. Connect the Kind node to the docker-compose backend network
3. Create the task-manager namespace and DATABASE_URL secret
4. Install ArgoCD via Helm
5. Apply the ArgoCD Application manifest

Report any task failures and suggest a fix. On success, remind the user that the api will be available at http://localhost:8080 once ArgoCD syncs.
