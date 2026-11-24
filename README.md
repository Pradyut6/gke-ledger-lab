# GKE Ledger Lab

A Kubernetes delivery lab built around a sample banking application. The frontend calls account, contact, balance, and ledger services. The account and ledger services use separate PostgreSQL StatefulSets. The portfolio overlay runs in a dedicated namespace on GKE and exposes the UI through an operator-controlled port forward.

| Control | Portfolio configuration |
| --- | --- |
| Service exposure | Internal ClusterIP Services |
| Signing key | Generate a fresh RSA key pair for each installation and store it in a Kubernetes Secret |
| Pod identity | Disable API credential automounting and remove the upstream cloud service-account binding |
| Network isolation | Deny ingress by default, allow internal API traffic, and restrict each PostgreSQL instance to its application clients |
| Cloud telemetry | Disabled in the lab until a project-owned identity and destination are configured |
| Release inputs | Use digest-pinned sample images and keep synthetic load scaled to zero by default |
| CI | Render the overlay, check the security controls, verify key generation, and scan source dependencies and checked-in secrets |

## Deploy to a test GKE cluster

Use a GKE cluster with NetworkPolicy enforcement, such as Autopilot or Standard with Dataplane V2. Configure kubectl for the intended cluster and use Bash, OpenSSL and kubectl for the following commands. [GKE network policies](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/network-policy)

~~~sh
kubectl config current-context
kubectl create namespace ledger-lab --dry-run=client -o yaml | kubectl apply -f -
bash scripts/generate-jwt-secret.sh | kubectl -n ledger-lab create -f -
kubectl apply -k deploy/portfolio
kubectl -n ledger-lab rollout status deployment/frontend --timeout=10m
kubectl -n ledger-lab port-forward service/frontend 8080:80
~~~

Open http://127.0.0.1:8080 and use the synthetic login presented by the UI. The sample databases and seed accounts are for an isolated lab. Use synthetic data exclusively. The initial deployment uses published Bank of Anthos images. To release your own changes, build and publish the affected service images to Artifact Registry, grant the cluster pull access, and pin the new digest in a Kustomize `images` override.

## Verify a change

~~~sh
kubectl kustomize deploy/portfolio > rendered.yaml
ruby scripts/check-portfolio.rb rendered.yaml
~~~

Check the rendered resource diff before deployment with `kubectl diff -k deploy/portfolio`. GitHub Actions performs manifest, dependency, and secret checks without cloud credentials.

## Operations

- **Unavailable UI**. Check the frontend Deployment, Service endpoints, and namespace events. A missing `jwt-key` Secret prevents pods that reference it from mounting their volumes.
- **Database connection timeout**. Check the database StatefulSet, Service endpoints, and the client pod's `app` label against the matching ingress rule.
- **Image release rollback**. Restore the prior image digest and reapply the overlay. Review each affected workload with `kubectl rollout status`.
- **Signing-key rotation**. Use a maintenance window. Generate a fresh Secret with the helper, update the existing Secret, and restart the issuer and all JWT consumers. Existing sessions will need to sign in again.
- **Teardown**. Delete the dedicated namespace when the lab and its state are no longer needed. Cluster cleanup is separate.

## Attribution

Adapted from Google’s [Bank of Anthos](https://github.com/GoogleCloudPlatform/bank-of-anthos). The application and published sample images are upstream work. The portfolio overlay, key provisioning, and release checks were added for this project. The original [Apache 2.0 license](LICENSE) and source notices are retained.
