provider "aws" {
 //profile	= "default"
 region		= "sa-east-1"
 // https://console.aws.amazon.com/iam/home?#/security_credentials$access_key
 access_key = "AKIAJS6TJ7SUFHWAQOGA"
 secret_key = "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"
}

resource "aws_kinesis_stream" "data_load_stream" {

  name = "data_load_stream"

  shard_count = 1

  retention_period = 24

  encryption_type = "NONE"

  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes"
  ]
  
}

resource "aws_s3_bucket" "raw_bucket" {
  bucket = "raw-picpay-test-123"
  acl = "private"
  force_destroy = true
}

resource "aws_s3_bucket" "cleaned_bucket" {
  bucket = "cleaned-picpay-test-123"
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
	prefix = "raw/"
    buffer_size = 5
    buffer_interval = 300

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

data "archive_file" "sanitize_lambda_zip" {
	type = "zip"
	source_dir = "sanitize_lambda"
	output_path = "sanitize_lambda.zip"
}

resource "aws_lambda_function" "sanitize_lambda" {

	function_name = "sanitize_lambda"
	handler = "sanitize_lambda.handler"

	filename = "sanitize_lambda.zip"
	source_code_hash = data.archive_file.sanitize_lambda_zip.output_base64sha256
	runtime = "python3.7"

	role = aws_iam_role.sanitize_lambda_role.arn

	depends_on = [
		aws_kinesis_stream.data_load_stream
	]

}

resource "aws_cloudwatch_log_group" "cleaned_stream_log_group" {
	name = "cleaned_stream_log_group"
}

resource "aws_cloudwatch_log_stream" "cleaned_stream_log_stream" {
	name = "cleaned_stream_log_stream"
	log_group_name = aws_cloudwatch_log_group.cleaned_stream_log_group.name
}

resource "aws_kinesis_firehose_delivery_stream" "cleaned_stream" {
  
	name = "cleaned_stream"
	destination = "extended_s3"

	kinesis_source_configuration {
		kinesis_stream_arn = aws_kinesis_stream.data_load_stream.arn
		role_arn = aws_iam_role.cleaned_firehose_role.arn
	}

  extended_s3_configuration  {

	role_arn = aws_iam_role.cleaned_firehose_role.arn
	bucket_arn = aws_s3_bucket.cleaned_bucket.arn
	prefix = "cleaned/"
    buffer_size = 5
    buffer_interval = 300

	processing_configuration {

		enabled = true

		processors {

			type = "Lambda"

			parameters {
				parameter_name = "LambdaArn"
				parameter_value = aws_lambda_function.sanitize_lambda.arn
			}

		}

	}

	cloudwatch_logging_options {
		enabled = true
		log_group_name = aws_cloudwatch_log_group.cleaned_stream_log_group.name
		log_stream_name = aws_cloudwatch_log_stream.cleaned_stream_log_stream.name
	}

  }

	depends_on = [
		aws_kinesis_stream.data_load_stream,
		aws_s3_bucket.cleaned_bucket,
		aws_lambda_function.sanitize_lambda,
		aws_kinesis_firehose_delivery_stream.raw_stream
	]

}

resource "aws_glue_catalog_database" "beers_catalog_database" {
	name = "beers"
}

resource "aws_glue_classifier" "aws_glue_csv_classifier" {

	name = "csv_classifier"

	csv_classifier {
		header = [ "id" , "name", "abv", "ibu", "target_fg", "target_og", "ebc", "srm", "ph"]
		contains_header = "ABSENT"
		delimiter = ","
		quote_symbol = "\""
	}

}

resource "aws_glue_crawler" "glue_csv_crawler" {

	name = "glue_csv_crawler"
	database_name = aws_glue_catalog_database.beers_catalog_database.name
	classifiers = [ aws_glue_classifier.aws_glue_csv_classifier.name ]
	role = aws_iam_role.glue_role.arn
	// https://docs.aws.amazon.com/glue/latest/dg/monitor-data-warehouse-schedule.html
	//schedule = "cron(*/5 * * * ? *)"

	configuration = jsonencode({
		Version = 1
		CrawlerOutput = {
			Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
		}
	})

	s3_target {
		path = "s3://${aws_s3_bucket.cleaned_bucket.bucket}/cleaned"
	}

	schema_change_policy {
		delete_behavior = "DEPRECATE_IN_DATABASE"
		update_behavior = "LOG"
	}
	
	recrawl_policy {
		recrawl_behavior = "CRAWL_EVERYTHING"
	}

}

data "archive_file" "data_load_lambda_zip" {
	type = "zip"
	source_dir = "data_load_lambda"
	output_path = "data_load_lambda.zip"
}

resource "aws_lambda_function" "data_load_lambda" {

	function_name = "data_load_lambda"
	handler = "data_load_lambda.handler"

	filename = "data_load_lambda.zip"
	source_code_hash = data.archive_file.data_load_lambda_zip.output_base64sha256
	runtime = "python3.7"

	role = aws_iam_role.data_load_lambda_role.arn

	depends_on = [ aws_kinesis_stream.data_load_stream ]
}

resource "aws_cloudwatch_event_rule" "every_five_minutes" {
 name = "every-five-minutes"
 description = "Fires grab_data every five minutes"
 schedule_expression = "rate(5 minutes)"
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