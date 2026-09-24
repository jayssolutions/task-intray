data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# Prometheus uses EC2 service discovery, which needs read access to instance metadata.
data "aws_iam_policy_document" "assume_ec2" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ec2_discovery" {
  statement {
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeAvailabilityZones",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "prometheus" {
  name               = "${var.project_name}-prometheus"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

resource "aws_iam_role_policy" "ec2_discovery" {
  name   = "ec2-service-discovery"
  role   = aws_iam_role.prometheus.id
  policy = data.aws_iam_policy_document.ec2_discovery.json
}

resource "aws_iam_instance_profile" "prometheus" {
  name = "${var.project_name}-prometheus"
  role = aws_iam_role.prometheus.name
}

resource "aws_security_group" "prometheus" {
  name   = "${var.project_name}-prometheus-sg"
  vpc_id = var.vpc_id

  ingress {
    description = "Prometheus UI and API"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "SSH for Ansible"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "prometheus" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.prometheus.id]
  iam_instance_profile        = aws_iam_instance_profile.prometheus.name
  associate_public_ip_address = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-prometheus"
    Role = "monitoring"
  }
}
