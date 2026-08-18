# Planar with a new VPC

This example creates an evaluation VPC and then deploys Planar into it. The included VPC submodule creates public and private subnets across two Availability Zones, an internet gateway, NAT gateway, and route tables.

For long-lived customer environments, use an organization-approved networking module or existing landing-zone VPC instead. The [`with-existing-vpc`](../with-existing-vpc) example represents that production-oriented model.

Replace every example identifier in `main.tf`, ensure the telemetry secret and public image exist, then run:

```shell
terraform init
terraform plan
terraform apply
```
