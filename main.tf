provider "aws" {
 profile	= "default"
 region		= "sa-east-1"
 access_key = "AKIAJS6TJ7SUFHWAQOGA"
 secret_key = "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"
}

resource "aws_kinesis_stream" "data_load_stream" {

  name = "data_load_stream"

  shard_count = 1

  retention_period = 24

  encryption_type = "NONE"

  shard_level_metrics = [
    "IncomingBytes",s
    "OutgoingBytes"
  ]
  
}

resource "aws_lambda_function" "data_load_lambda" {

 function_name = "data_load_lambda"
 handler = "data_load_lambda.handler"

 filename = "data_load_lambda.zip"
 source_code_hash = filebase64sha256("data_load_lambda.zip")
 runtime = "python3.7"

 role = aws_iam_role.data_load_lambda_role.arn

 depends_on = [
   aws_kinesis_stream.data_load_stream
 ]

}

resource "aws_cloudwatch_event_rule" "every_five_minutes" {
 name = "every-five-minutes"
 description = "Fires grab_data every five minutes"
 schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "check_every_five_minutes" {
 rule = aws_cloudwatch_event_rule.every_five_minutes.name
 target_id = "data_load_lambda"
 arn = aws_lambda_function.data_load_lambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
 statement_id = "AllowExecutionFromCloudWatch"
 action = "lambda:InvokeFunction"
 function_name = aws_lambda_function.data_load_lambda.function_name
 principal = "events.amazonaws.com"
 source_arn = aws_cloudwatch_event_rule.every_five_minutes.arn
}