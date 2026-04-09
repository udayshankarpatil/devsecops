Tear down the local Kind cluster for task-manager.

Run from the repo root (host machine — not inside the devcontainer):

```bash
ansible-playbook ops/ansible/kind-down.yml
```

The playbook is idempotent — safe to run when the cluster is already absent.
Docker Compose services (postgres, kafka) are left running.

After confirming success, remind the user to run `docker compose down` separately if they also want to stop the infrastructure.
