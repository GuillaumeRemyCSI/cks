resource "aws_security_group" "nodes" {
  name        = "${local.prefix}-nodes"
  description = "${local.prefix}-nodes"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.access_cidrs
    description = "ssh"
  }

  # Kubernetes and the CNI need every port between cp and worker.
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags_common
}
