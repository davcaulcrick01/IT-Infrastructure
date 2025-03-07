resource "aws_iam_role" "ssm_role" {
  name               = "SSMRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "ec2.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "ssm_policy" {
  name        = "SSMManagedInstancePolicy"
  description = "Policy for SSM to manage instances"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "ssm:DescribeInstanceInformation",
          "ssm:SendCommand",
          "ssm:ListCommands",
          "ssm:GetCommandInvocation",
          "ssm:StartSession",
          "ssm:DescribeSessions",
          "ssm:TerminateSession",
          "ec2messages:*",
          "ssmmessages:*"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = aws_iam_policy.ssm_policy.arn
}

resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "SSMInstanceProfile"
  role = aws_iam_role.ssm_role.name
}
