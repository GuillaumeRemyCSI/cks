# Bare Ubuntu nodes: Kubernetes is installed by the participants with the course scripts.
# No instance profile on purpose: participants have sudo, so there must be no credentials to steal.
resource "aws_instance" "node" {
  for_each = toset(var.nodes)

  ami                         = data.aws_ami.ubuntu.image_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnets[0]
  vpc_security_group_ids      = [aws_security_group.nodes.id]
  associate_public_ip_address = true
  # Lets pod traffic routed by the CNI leave the instance unchanged.
  source_dest_check = false

  user_data = templatefile("${path.module}/template/node.sh", {
    hostname = each.key
    password = random_string.student.result
  })

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = merge(var.tags_common, { "Name" = "${local.prefix}-${each.key}" })

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}
