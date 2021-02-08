resource "aws_iam_role" "data_load_lambda_role" {
  name = "data_load_lambda_role"
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

data "aws_iam_policy_document" "data_load_lambda_policy_document" {
  
  statement {
    effect = "Allow"
    actions = [ "kinesis:PutRecord" ]
    resources = [ aws_kinesis_stream.data_load_stream.arn ]
  }

  statement {
    effect = "Allow"
    actions = [ "logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [ "*" ]
  }

}

resource "aws_iam_policy" "data_load_lambda_policy" {
  name = "data_load_lambda_policy"
  policy = data.aws_iam_policy_document.data_load_lambda_policy_document.json
}

resource "aws_iam_role_policy_attachment" "data_load_lambda_policy_attachment" {
  role = aws_iam_role.data_load_lambda_role.name
  policy_arn = aws_iam_policy.data_load_lambda_policy.arn
}