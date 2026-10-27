resource "aws_iam_role" "server" {
  name               = "${local.prefix}-${var.app_name}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  tags               = local.tags_all

}

# The bucket also holds every environment's Terraform state (SSH passwords included), and
# participants have sudo on these VMs: S3 access stays limited to this environment's prefix.
resource "aws_iam_policy" "server" {
  name   = "${local.prefix}-${var.app_name}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeAddresses",
                "ec2:DescribeInstances",
                "cloudwatch:PutMetricData",
                "ec2:DescribeTags",
                "ec2:DescribeRegions",
                "ec2:DescribeHosts",
                "cloudwatch:PutMetricStream",
                "ec2:DescribeVolumeStatus",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeVpcs",
                "ec2:DescribeVolumes",
                "ec2:DescribeSubnets",
                "ec2:DescribeInstanceStatus"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": "arn:aws:s3:::${var.s3_k8s_config}/config/${local.USER_ID}/${local.ENV_ID}/*"
        },
        {
            "Effect": "Allow",
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::${var.s3_k8s_config}",
            "Condition": {
                "StringLike": {
                    "s3:prefix": "config/${local.USER_ID}/${local.ENV_ID}/*"
                }
            }
        }
    ]
}
EOF
}

resource "aws_iam_policy" "server-eks" {
  for_each = toset(var.aws_eks_cluster_eks_cluster_arn == "" ? [] : ["enable"])
  name     = "${local.prefix}-${var.app_name}-eks"
  policy   = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "eks:*"
            ],
            "Resource": "${var.aws_eks_cluster_eks_cluster_arn}"
        }
    ]
}
EOF
}


resource "aws_iam_policy_attachment" "server" {
  name       = "${local.prefix}-${var.app_name}"
  policy_arn = aws_iam_policy.server.arn
  roles      = [aws_iam_role.server.name]
}

resource "aws_iam_policy_attachment" "server-eks" {
  for_each   = toset(var.aws_eks_cluster_eks_cluster_arn == "" ? [] : ["enable"])
  name       = "${local.prefix}-${var.app_name}-eks"
  policy_arn = aws_iam_policy.server-eks["enable"].arn
  roles      = [aws_iam_role.server.name]
}


resource "aws_iam_instance_profile" "server" {
  name = "${local.prefix}-${var.app_name}"
  role = aws_iam_role.server.name
}
