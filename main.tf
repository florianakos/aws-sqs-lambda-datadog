provider "aws" {
  region = "eu-central-1" // -> Frankfurt
  profile = "personal-aws"
}

variable "ddg_api_key" {
  type = string
}

variable "ddg_app_key" {
  type = string
}

resource "aws_iam_role" "ddg_aws_project_role" {
  name               = "DataDogAWSProjectRole"
  description        = "Role that allowed to be assumed by AWS Lambda, which will be taking all actions."
  tags = {
      owner = "tfExerciseBoss"
  }
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "basic-exec-role" {
  role       = aws_iam_role.ddg_aws_project_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "s3_lambda_access" {
  name   = "s3_lambda_access"
  path   = "/"
  policy = data.aws_iam_policy_document.s3_lambda_access.json
}

data "aws_iam_policy_document" "s3_lambda_access" {
  statement {
    effect    = "Allow"
    resources = ["arn:aws:s3:::gm-monitoring/*"]
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
    ]
  }
}

resource "aws_iam_role_policy_attachment" "s3_lambda_access" {
  role       = aws_iam_role.ddg_aws_project_role.name
  policy_arn = aws_iam_policy.s3_lambda_access.id
}

data "aws_iam_policy_document" "sqs_lambda_access" {
  statement {
    sid       = "AllowSQSPermissions"
    effect    = "Allow"
    resources = ["arn:aws:sqs:eu-central-1:546454927816:gm-monitoring-queue"]
    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
      "sqs:GetQueueAttributes",
    ]
  }
}

resource "aws_iam_policy" "sqs_lambda_access" {
  name   = "sqs_lambda_access"
  policy = data.aws_iam_policy_document.sqs_lambda_access.json
}

resource "aws_iam_role_policy_attachment" "sqs_lambda_access" {
  policy_arn = aws_iam_policy.sqs_lambda_access.id
  role       = aws_iam_role.ddg_aws_project_role.name
}

resource "aws_lambda_function" "lambda_function" {
  role             = aws_iam_role.ddg_aws_project_role.arn
  handler          = "ddg_metric_submit.handler"
  runtime          = "python3.6"
  filename         = "ddg_metric_submit.zip"
  function_name    = "ddg_aws_func"
  source_code_hash = base64sha256(filebase64("ddg_metric_submit.zip"))
  environment {
    variables = {
      DDG_API_KEY = var.ddg_api_key
      DDG_APP_KEY = var.ddg_app_key
    }
  }
}

resource "aws_lambda_function" "lambda_mock_datasource" {
  role             = aws_iam_role.ddg_aws_project_role.arn
  handler          = "ddg_mock_datasource.handler"
  runtime          = "python3.6"
  filename         = "ddg_mock_datasource.zip"
  function_name    = "ddg_mock_datasource"
  source_code_hash = base64sha256(filebase64("ddg_mock_datasource.zip"))
}

resource "aws_lambda_permission" "allow_cloudwatch_events_call" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_mock_datasource.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.mock_data_generate_schedule.arn
}

resource "aws_cloudwatch_event_rule" "mock_data_generate_schedule" {
  name                = "mock_data_generate_schedule"
  description         = "Periodic call to AWS Lambda function"
  schedule_expression = "cron(0/1 * * * ? *)"
}

resource "aws_cloudwatch_event_target" "lambda_target_details" {
  arn       = aws_lambda_function.lambda_mock_datasource.arn
  rule      = aws_cloudwatch_event_rule.mock_data_generate_schedule.name
  target_id = "AWSLambdaFuncMockDataSource"
}

resource "aws_lambda_permission" "allow_sqs_invoke_lambda" {
  statement_id  = "AllowExecutionFromSQS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "sqs.amazonaws.com"
  source_arn    = aws_sqs_queue.message_queue.arn
}

resource "aws_sqs_queue" "message_queue" {
  name                      = "gm-monitoring-queue"
  delay_seconds             = 15
  max_message_size          = 2048
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
  tags = {
    Owner = "Flo"
    Project = "DataDog-AWS-Integration"
  }
}

resource "aws_sqs_queue_policy" "sqs_policy" {
  queue_url = aws_sqs_queue.message_queue.id
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "${aws_sqs_queue.message_queue.arn}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${aws_s3_bucket.ddg_aws_bucket.arn}"
        }
      }
    }
  ]
}
POLICY
}

resource "aws_lambda_event_source_mapping" "sqs_lambda_trigger" {
  event_source_arn = aws_sqs_queue.message_queue.arn
  function_name    = aws_lambda_function.lambda_function.function_name
  batch_size       = 1
}

resource "aws_s3_bucket" "ddg_aws_bucket" {
  bucket = "gm-monitoring"
  tags = {
    Name        = "My bucket for DataDog AWS integration proejct..."
    Environment = "Dev"
  }
  force_destroy = "true"
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.ddg_aws_bucket.id
  queue {
    queue_arn     = aws_sqs_queue.message_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".json"
  }
}
