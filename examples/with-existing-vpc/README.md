# Planar with existing customer infrastructure

This example is the recommended starting point for customer-managed AWS deployments. It uses:

- Existing public and private subnets.
- An existing Route 53 hosted zone.
- An existing ECR repository.
- An existing Secrets Manager telemetry token.
- External application CI/CD as the owner of ECS service revisions.

Replace every example identifier in `main.tf`, then run:

```shell
terraform init
terraform plan
terraform apply
```

In a customer repository, replace the relative module source with an immutable release tag:

```hcl
source = "git::https://github.com/coplane/terraform-aws-planar.git?ref=v0.10.0"
```

The initial image tag must exist before the first apply. After provisioning, the application pipeline should use the `deployment` output to update the ECS service as described in the root README.
