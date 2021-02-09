resource "aws_iam_role" "sanitize_lambda_role" {
  name = "sanitize_lambda_role"
  assume_role_policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "sanitize_lambda_policy_document" {
  
  statement {
    effect = "Allow"
    actions = [ "logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [ "*" ]
  }

}

resource "aws_iam_policy" "sanitize_lambda_policy" {
  name = "sanitize_lambda_policy"
  policy = data.aws_iam_policy_document.sanitize_lambda_policy_document.json
}

resource "aws_iam_role_policy_attachment" "sanitize_lambda_policy_attachment" {
  role = aws_iam_role.sanitize_lambda_role.name
  policy_arn = aws_iam_policy.sanitize_lambda_policy.arn
}