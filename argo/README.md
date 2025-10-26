# Argo Workflow integration for `setup-grafana-monitoring.sh`

This directory contains the Kubernetes manifests required to execute the
[`setup-grafana-monitoring.sh`](../setup-grafana-monitoring.sh) script in an
[Argo Workflows](https://argo-workflows.readthedocs.io/) environment. The
workflow provisions the Grafana Kubernetes Monitoring stack without any
interactive prompts by supplying every configuration value as a workflow
parameter.

## Contents

- `kustomization.yaml` – Generates a ConfigMap with the setup script and applies
  the workflow template in the `argo` namespace.
- `workflowtemplate.yaml` – Defines the reusable `WorkflowTemplate` that wraps
  the setup script in a container with `kubectl` and `helm` installed.
- `workflow.yaml` – Example `Workflow` manifest that references the template and
  provides sample parameter values.

## Prerequisites

1. **Argo Workflows controller** available in the target cluster.
2. A service account named `argo-workflow` in the `argo` namespace with
   permission to manage resources in the namespaces targeted by the script
   (defaults to `grafana-agent`). Adjust the `serviceAccountName` in
   `workflowtemplate.yaml` if you use a different account.
3. `kubectl`, `helm`, and appropriate Kubernetes access for the chosen service
   account.
4. A secret named `grafana-monitoring-credentials` in the `argo` namespace
   containing the Grafana password or API token. The secret must include a key
   called `password`. For example:

   ```bash
   kubectl -n argo create secret generic grafana-monitoring-credentials \
     --from-literal=password="<grafana-token>"
   ```

   Alternatively, supply the password through the `grafana-password` workflow
   parameter (less secure).

## Deployment

1. Apply the Kustomize bundle to create the ConfigMap and the workflow template:

   ```bash
   kubectl apply -k argo/
   ```

2. Run the workflow with your desired parameters. You can either submit the
   template directly:

   ```bash
   argo submit --from workflowtemplate/grafana-monitoring-setup \
     -n argo \
     -p cluster-name=my-cluster \
     -p customer-id=customer01 \
     -p region=us-east-1 \
     -p project-id=my-project \
     -p cloud-platform=aws \
     -p stage=prod \
     -p env-type=prod \
     -p username=123456
   ```

   or apply the example workflow and edit the sample values:

   ```bash
   kubectl apply -f argo/workflow.yaml
   ```

3. Monitor progress using the Argo UI or `argo watch` CLI command.

The script automatically runs in non-interactive mode within the workflow. When
the run completes successfully, the temporary `values-<cluster>.yaml` file is
removed, and Helm releases are created in the `grafana-agent` namespace as in
manual executions.
