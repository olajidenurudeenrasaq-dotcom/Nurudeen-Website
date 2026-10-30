# Nurudeen's Website

Terraform deploys a small two-tier AWS website:

- **Client tier:** a public EC2 instance running Apache HTTP Server (`httpd`). Its homepage says “Welcome to Nurudeen's website!” and its `/middle` path proxies requests to the private middle tier.
- **Middle tier:** a private EC2 instance running Apache on port 8080. It has no public IP and accepts traffic only from the client tier's security group.
- **Network:** a VPC with public and private subnets, an internet gateway, and a NAT gateway for private-instance package installation and updates.
- **Website address:** an Elastic IP is attached to the client instance, so the public IP stays the same if that instance is replaced during this deployment.

The EC2 instance's AWS **Name** tag is `Nurudeen Website`. The public address remains an IP address; the deployment also prints a clickable HTTP URL.

## Important costs

This deployment creates two EC2 instances, two Elastic IP addresses, and a NAT gateway. NAT gateways are billed hourly and for data processed, even when idle. Review current AWS pricing for your region and run the destroy workflow when you no longer need the environment. The S3 Terraform state bucket is not created or destroyed by this project.

## Prerequisites

1. An AWS account and permission to create/manage VPCs, subnets, routes, security groups, EC2 instances, and Elastic IPs.
2. Terraform 1.7.5 (or a compatible Terraform version) and AWS CLI for local use.
3. An S3 bucket named `terraform-lwplabs-olajide` in `us-east-1` for the remote Terraform state. Create it before the first deployment; enable bucket versioning and block public access. The state key for this project is `nurudeens-website/terraform.tfstate`, separate from other projects' state keys in that bucket.
4. For GitHub Actions, add repository Actions secrets named `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. Use credentials with only the permissions needed for this deployment and the S3 state bucket. Do not put credentials in `terraform.tfvars`.
5. Keep `AWS_REGION` in `terraform.tfvars` and the `AWS_REGION` setting in both workflow files aligned. The S3 backend is currently configured for `us-east-1`.

## GitHub Actions setup and use

1. Put this project in its own GitHub repository with these files—including `.github/workflows/`—at the repository root. This project is currently inside another repository's subfolder; pushing only the parent repository will not run these nested workflows.
2. Ensure the repository's default deployment branch is `main`.
3. Configure the AWS Actions secrets and prepare the S3 state bucket as described above.
4. Push or merge a commit to `main`. **Deploy Nurudeen Website** initializes and validates Terraform, applies the infrastructure, and prints the URL in the workflow run summary.
5. Open **Actions > Destroy Nurudeen Website > Run workflow** to remove the deployment. Enter exactly `destroy` in `confirm_destroy` and run the workflow. Any other value fails without accessing AWS.

For a new GitHub repository, create the repository without a README, then from this folder run:

```shell
git init -b main
git add .
git commit -m "Add Nurudeen website infrastructure"
git remote add origin https://github.com/<OWNER>/<REPOSITORY>.git
git push -u origin main
```

The destroy workflow removes resources tracked in this Terraform state, but it does not delete the S3 bucket or state object.

## Local Terraform commands

Run these commands from this folder, after configuring AWS CLI credentials and creating the state bucket:

```shell
terraform init
terraform validate
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
terraform output website_url
```

To remove the resources locally:

```shell
terraform destroy -var-file="terraform.tfvars"
```

The resulting `website_url` is also printed as a raw value with:

```shell
terraform output -raw website_url
```

## Configuration

Edit `terraform.tfvars` to set the AWS region, an availability zone in that region, and the EC2 instance type. If you change the region, also update the backend region in `versions.tf` and `AWS_REGION` in both workflows. The configured availability zone must belong to the selected region.

The public website is served over HTTP on port 80. The private middle tier is reachable only from the client EC2 security group on port 8080. No inbound SSH access is configured.
