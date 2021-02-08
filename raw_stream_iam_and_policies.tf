resource "aws_iam_role" "raw_firehose_role" {
  name = "raw_firehose_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "raw_firehose_policy_document" {

  statement {
    effect = "Allow"
    actions = [ "kinesis:*" ]
    resources = [ aws_kinesis_stream.data_load_stream.arn ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:PutObjectAcl",
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject"
    ]
    resources = [ 
      "${aws_s3_bucket.raw_bucket.arn}",
      "${aws_s3_bucket.raw_bucket.arn}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [ "logs:PutLogEvents" ]
    resources = [ "*" ]
  }

}

resource "aws_iam_policy" "raw_firehose_policy" {
  name = "raw_firehose_policy"
  policy = data.aws_iam_policy_document.raw_firehose_policy_document.json
}

resource "aws_iam_role_policy_attachment" "raw_firehose_policy_attachment" {
  role = aws_iam_role.raw_firehose_role.name
  policy_arn = aws_iam_policy.raw_firehose_policy.arn
}