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

resource "aws_s3_bucket" "raw_bucket" {
  bucket = "raw-picpay-test-123"
  acl = "private"
  force_destroy = true
}

resource "aws_cloudwatch_log_group" "raw_stream_log_group" {
  name = "raw_stream_log_group"
}

resource "aws_cloudwatch_log_stream" "raw_stream_log_stream" {
  name = "raw_stream_log_stream"
  log_group_name = aws_cloudwatch_log_group.raw_stream_log_group.name
}

resource "aws_kinesis_firehose_delivery_stream" "raw_stream" {
  
  name = "raw_stream"
  destination = "s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.data_load_stream.arn
    role_arn = aws_iam_role.raw_firehose_role.arn
  }

  s3_configuration {

    role_arn = aws_iam_role.raw_firehose_role.arn
    bucket_arn = aws_s3_bucket.raw_bucket.arn
    buffer_size = 1
    buffer_interval = 60

    cloudwatch_logging_options {
      enabled = true
      log_group_name = aws_cloudwatch_log_group.raw_stream_log_group.name
      log_stream_name = aws_cloudwatch_log_stream.raw_stream_log_stream.name
    }

  }

  depends_on = [
    aws_kinesis_stream.data_load_stream,
    aws_s3_bucket.raw_bucket
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