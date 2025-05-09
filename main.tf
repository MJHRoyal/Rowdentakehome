provider "aws" {
  region = "us-east-1" 
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_ec2_role" {
  name = "lambda_ec2_control_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# IAM Policy for EC2 control
resource "aws_iam_policy" "lambda_ec2_policy" {
  name = "lambda_ec2_control_policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ec2:DescribeInstances",
          "ec2:StopInstances"
        ],
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.lambda_ec2_role.name
  policy_arn = aws_iam_policy.lambda_ec2_policy.arn
}

# Attach AWS managed policy for basic Lambda logging
resource "aws_iam_role_policy_attachment" "attach_logging" {
  role       = aws_iam_role.lambda_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda function
resource "aws_lambda_function" "rowdenstest_lambda" {
  function_name = "rowdenstest"
  role          = aws_iam_role.lambda_ec2_role.arn
  handler       = "rowdenstest.lambda_handler"
  runtime       = "python3.9"

  filename         = "rowdenstest.zip"
  source_code_hash = filebase64sha256("rowdenstest.zip")

  timeout = 30
}

# EventBridge Rule (Runs Lambda every hour)
resource "aws_cloudwatch_event_rule" "lambda_schedule" {
  name                = "rowdenstest-schedule"
  description         = "Triggers the Lambda every hour"
  schedule_expression = "cron(0 * * * ? *)"
  state               = "ENABLED"
}

# EventBridge Target - attach rule to Lambda
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.lambda_schedule.name
  target_id = "rowdenstest-lambda"
  arn       = aws_lambda_function.rowdenstest_lambda.arn
}

# Lambda permission to allow EventBridge to invoke it
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rowdenstest_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_schedule.arn

  # This fixes ordering issues by ensuring the rule exists before permission is created
  depends_on = [aws_cloudwatch_event_rule.lambda_schedule]
}


