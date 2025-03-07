########################################
# S3 Bucket
########################################
resource "aws_s3_bucket" "Grey_bucket" {
  bucket = local.bucket_name

  tags = {
    Name = "${local.name_prefix}-S3-Bucket"
  }
}

########################################
# Bucket Policy (Optional)
########################################
resource "aws_s3_bucket_policy" "Grey_bucket_policy" {
  bucket = aws_s3_bucket.Grey_bucket.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${local.bucket_name}/*"
    }
  ]
}
POLICY
}
