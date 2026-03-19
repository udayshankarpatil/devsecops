Show the current ArgoCD sync status for the task-manager application.

```bash
kubectl get application task-manager -n argocd -o wide
kubectl get pods -n task-manager
```

Summarise:
- Whether the application is Synced and Healthy
- Which image SHA is currently deployed (from the pod image tag)
- Any pods that are not Running, with a likely cause
- If OutOfSync, what has changed since the last sync
