resource "aws_s3_bucket" "data_lake" {
  bucket = "${var.group}-${var.team}-${var.use_case}-${var.service}"

  tags = {
    Environment = var.environment
  }
}

resource "aws_s3_object" "lambda_folder" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "muchen_source_data/"

  tags = local.common_tags
}

resource "aws_vpc" "main_vpc" {
  cidr_block           = "20.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.common_tags
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags   = local.common_tags
}

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "20.0.0.0/24"

  tags = local.common_tags

}

resource "aws_subnet" "private_subnet_a" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "20.0.10.0/24"
  availability_zone = "eu-west-2a"

  tags = local.common_tags
}

resource "aws_subnet" "private_subnet_b" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "20.0.20.0/24"
  availability_zone = "eu-west-2b"

  tags = local.common_tags
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id

  tags = local.common_tags
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = local.common_tags
}

resource "aws_route_table_association" "pri_rt_asso_a" {
  subnet_id      = aws_subnet.private_subnet_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "pri_rt_asso_b" {
  subnet_id      = aws_subnet.private_subnet_b.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "pub_rt_asso" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "lambda_sg" {
  name        = "allow_lambda_outbound"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.main_vpc.id

  tags = {
    Name = "allow_tls"
  }
}


resource "aws_vpc_security_group_egress_rule" "lambda_outboud_s3" {
  security_group_id = aws_security_group.lambda_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp" 
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "lambda_outboud_rds" {
  security_group_id = aws_security_group.lambda_sg.id
  cidr_ipv4         = aws_vpc.main_vpc.cidr_block
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432

}


resource "aws_security_group" "rds_lambda_sg" {
  name        = "rds_allow_lambda"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.main_vpc.id

  tags = {
    Name = "allow_tls"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_inbound_lambda" {
  security_group_id            = aws_security_group.rds_lambda_sg.id
  referenced_security_group_id = aws_security_group.lambda_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main_vpc.id
  service_name      = "com.amazonaws.eu-west-2.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_rt.id]
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main_vpc.id
  service_name        = "com.amazonaws.eu-west-2.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_subnet_a.id, aws_subnet.private_subnet_b.id]
  security_group_ids  = [aws_security_group.lambda_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_security_group_ingress_rule" "ssm_endpoint_inbound" {
  security_group_id            = aws_security_group.lambda_sg.id
  referenced_security_group_id = aws_security_group.lambda_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_db_subnet_group" "lambda_rds" {
  name       = "main"
  subnet_ids = [aws_subnet.private_subnet_a.id, aws_subnet.private_subnet_b.id]

  tags = {
    Name = "My RDS subnet group"
  }
}



resource "aws_iam_role" "lambda_ex_role" {
  name = "lambda_ex_role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    tag-key = "tag-value"
  }
}

resource "aws_iam_policy" "s3_full_access" {
  name        = "lambda_s3_full_access"
  path        = "/"
  description = "Access S3 Objects"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({

    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:*",
          "s3-object-lambda:*"
        ],
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_policy" "ecr_access" {
  name        = "lambda_ecr_access"
  path        = "/"
  description = "Write images to ECR access"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({

    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:GetLifecyclePolicy",
          "ecr:GetLifecyclePolicyPreview",
          "ecr:ListTagsForResource",
          "ecr:DescribeImageScanFindings"
        ],
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_policy" "ssm_access" {
  name        = "ssm_access"
  path        = "/"
  description = "Pull SSM credential"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : ["ssm:GetParameter"],
        "Resource" : "*"
      },
    #   {
    #     "Effect" : "Allow",
    #     "Action" : ["kms:Decrypt"],
    #     "Resource" : "*"
    #   }
    ]
  })
}



resource "aws_iam_policy" "ec2_access" {
  name        = "lambda_ec2_access"
  path        = "/"
  description = "create network interface access"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "ec2:*",
        "Effect" : "Allow",
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : "elasticloadbalancing:*",
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : "cloudwatch:*",
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : "autoscaling:*",
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : "iam:CreateServiceLinkedRole",
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "iam:AWSServiceName" : [
              "autoscaling.amazonaws.com",
              "ec2scheduled.amazonaws.com",
              "elasticloadbalancing.amazonaws.com",
              "spot.amazonaws.com",
              "spotfleet.amazonaws.com",
              "transitgateway.amazonaws.com"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "cloudwatch_access" {
  name        = "cloudwatch_access"
  path        = "/"
  description = "write logs to cloudwatch"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_attach" {
  role       = aws_iam_role.lambda_ex_role.name
  policy_arn = aws_iam_policy.cloudwatch_access.arn
}

resource "aws_iam_role_policy_attachment" "s3_attach" {
  role       = aws_iam_role.lambda_ex_role.name
  policy_arn = aws_iam_policy.s3_full_access.arn
}

resource "aws_iam_role_policy_attachment" "ecr_attach" {
  role       = aws_iam_role.lambda_ex_role.name
  policy_arn = aws_iam_policy.ecr_access.arn
}

resource "aws_iam_role_policy_attachment" "ec2_attach" {
  role       = aws_iam_role.lambda_ex_role.name
  policy_arn = aws_iam_policy.ec2_access.arn
}


resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.lambda_ex_role.name
  policy_arn = aws_iam_policy.ssm_access.arn
}

resource "aws_ecr_repository" "lambda_ecr" {
  name                 = "lambda_ecr"
  image_tag_mutability = "MUTABLE"

}
