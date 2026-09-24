# task-intray

A small Node.js (Express) service deployed end to end on AWS. Terraform provisions the network, an Application Load Balancer and EC2 instances; Ansible installs and runs the app as a systemd service; Prometheus and the ELK stack provide metrics and logs; GitHub Actions lints, tests and packages everything.

## Architecture

```mermaid
flowchart LR
    user([Client]) -->|HTTP :80| alb[Application Load Balancer]
    subgraph vpc[VPC 10.30.0.0/16 - 2 public subnets across 2 AZs]
        alb -->|:3000| ec2a[EC2 app-1<br/>systemd: task-intray]
        alb -->|:3000| ec2b[EC2 app-2<br/>systemd: task-intray]
    end
    admin([Operator / Ansible]) -->|SSH :22 from admin_cidr| ec2a & ec2b
    prom[Prometheus] -.->|scrape /metrics<br/>EC2 service discovery| ec2a & ec2b
    ec2a & ec2b -.->|journald → Filebeat| ls[Logstash] --> es[(Elasticsearch)]
```

- **Load balancer** listens on port 80 and health-checks `GET /health` on each instance.
- **Instances** run Amazon Linux 2023 with Node.js 22; the app listens on port 3000, reachable only from the load balancer (and optionally from `monitoring_cidrs`).
- **Terraform state** is stored in S3 with native lock files (`use_lockfile`).

## Repository layout

| Path | Contents |
|---|---|
| `app/` | Express app (`src/`), Jest tests (`test/`) |
| `terraform/` | Root module plus `network`, `alb` and `compute` modules |
| `ansible/` | Playbook, systemd unit template, collection requirements |
| `scripts/build_inventory.sh` | Builds the Ansible inventory from Terraform outputs |
| `monitoring/` | Prometheus scrape config and alert rules |
| `logging/` | Filebeat and Logstash configs |
| `.github/workflows/ci.yml` | CI pipeline |

## Application endpoints

| Endpoint | Purpose |
|---|---|
| `GET /` | Service name, status and hostname |
| `GET /health` | Liveness check (used by the load balancer) |
| `GET /ready` | Readiness check |
| `GET /metrics` | Prometheus metrics: default process metrics plus `http_request_duration_seconds` |
| `GET /error` | Returns 500, for testing alerts |

## Run the app locally

Requires Node.js 22 or later.

```bash
cd app
npm ci
npm test        # lint with: npm run lint
npm start       # listens on http://localhost:3000 (override with PORT)
```

## Deploy to AWS

### Prerequisites

- An AWS account and credentials for the AWS CLI / Terraform (for example `aws configure` or `AWS_PROFILE`)
- Terraform 1.10 or later
- Ansible (with `ansible-galaxy`), `jq` and `bash`. On Windows, run the Ansible steps from WSL.
- An SSH key pair; the public key goes into Terraform, the private key is used by Ansible

### 1. Create the state bucket (once)

Terraform stores its state in the S3 bucket named in [`terraform/backend.tf`](terraform/backend.tf), and that bucket must exist before `terraform init`. Either create a bucket with that name, or change `bucket` and `region` in `backend.tf` to one you own. Enable versioning so older state can be recovered:

```bash
aws s3api create-bucket --bucket <state-bucket> --region us-east-1
aws s3api put-bucket-versioning --bucket <state-bucket> --versioning-configuration Status=Enabled
```

### 2. Provision the infrastructure

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

| Variable | Description | Default |
|---|---|---|
| `public_key` | SSH public key content (required) | — |
| `admin_cidr` | Your IP as a /32, allowed to SSH for Ansible | `127.0.0.1/32` (no access) |
| `aws_region` | AWS region | `us-east-1` |
| `instance_count` | Number of EC2 instances | `2` |
| `instance_type` | EC2 instance type | `t3.micro` |
| `monitoring_cidrs` | CIDRs allowed to scrape port 3000 | `[]` |
| `project_name` | Prefix for resource names | `task-intray` |

`terraform.tfvars` is git-ignored. Then:

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Outputs: `application_url` (the load balancer URL) and `instance_public_ips`.

### 3. Build the Ansible inventory

```bash
./scripts/build_inventory.sh
```

This writes `ansible/inventory.ini` (git-ignored) with one line per instance.

### 4. Package the app

From the repository root:

```bash
tar -czf app.tar.gz -C app package.json package-lock.json src
```

CI also builds this archive on every run; you can download it from the workflow run's artifacts instead.

### 5. Deploy with Ansible

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook playbook.yml --private-key ~/.ssh/<your-key>
```

The playbook deploys to one host at a time (`serial: 1`) and restarts the service when the code, dependencies or unit file change. It reads `../app.tar.gz` by default; set `APP_ARCHIVE=/path/to/app.tar.gz` to use another archive.

### 6. Check it works

```bash
curl "$(terraform -chdir=terraform output -raw application_url)/health"
```

Instances can take a minute to pass the load balancer's health checks after a deploy.

### Tear down

```bash
cd terraform
terraform destroy
```

The state bucket is not managed by Terraform and is left in place.

## Monitoring and logging

The configs in `monitoring/` and `logging/` are **reference configs**: nothing in this repo deploys Prometheus, Filebeat or ELK.

- **Prometheus** ([`monitoring/prometheus.yml`](monitoring/prometheus.yml)) discovers instances through EC2 service discovery using the `Role=application` tag and scrapes their private IPs on port 3000. The Prometheus host needs the `ec2:DescribeInstances` permission, and its CIDR must be in `monitoring_cidrs`.
- **Alerts** ([`monitoring/alerts.yml`](monitoring/alerts.yml)): 5xx error rate above 5%, process CPU above 80%, resident memory above 500 MB (each sustained for 5 minutes).
- **Logs**: the app writes JSON lines to stdout, which systemd sends to journald. Filebeat reads the `task-intray.service` unit's journal and ships it to Logstash, which parses the JSON and indexes into `task-intray-YYYY.MM.dd`.

## CI

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs on pull requests, pushes to `main`, and manually:

| Job | Checks |
|---|---|
| App | `npm ci`, ESLint, Jest with coverage; uploads `app.tar.gz` and the coverage report as artifacts |
| Terraform | `fmt -check`, `validate`, tflint, Checkov (report-only for now) |
| Ansible | `ansible-lint` |
| Configs | ShellCheck on `scripts/`, `promtool check rules` on the alert rules |

## Known limitations

This is an exercise setup; before using it for anything real:

- Instances have public IPs and SSH is open to `admin_cidr`. Private subnets with SSM Session Manager would remove port 22.
- The load balancer serves plain HTTP; `/metrics` and `/error` are publicly reachable through it.
- Ansible skips SSH host-key checking.
- Deploys aren't health-checked per host and there is no rollback.
