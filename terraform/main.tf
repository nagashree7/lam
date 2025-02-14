provider "aws" {
  region = var.region
}

# Define region variable
variable "region" {
  description = "The AWS region to deploy resources into."
  type        = string
  default     = "us-east-1"
}

# Get AWS account ID dynamically
data "aws_caller_identity" "current" {}

# Create random pet for S3 bucket name
resource "random_pet" "s3_bucket_name" {
  length = 2  # Generates two words
}

# Create S3 bucket with random name
resource "aws_s3_bucket" "my_bucket" {
  bucket        = "my-unique-s3-bucket-${lower(random_pet.s3_bucket_name.id)}"  # Ensure the name is lowercase
  force_destroy = true
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda-role-${random_pet.lambda_policy_suffix.id}"  # Make the role name unique
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}


# Random pet for Lambda policy suffix
resource "random_pet" "lambda_policy_suffix" {
  length = 2
}

# IAM Policy for Lambda to Access S3 and CloudWatch Logs
resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_s3_cloudwatch_policy_${random_pet.lambda_policy_suffix.id}"
  description = "Policy for Lambda to read S3 and write logs to CloudWatch"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "${aws_s3_bucket.my_bucket.arn}/*",
        "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"
      ]
    }
  ]
}
EOF
}

# Attach Policy to Lambda Role
resource "aws_iam_role_policy_attachment" "lambda_s3_cloudwatch_attach" {
  policy_arn = aws_iam_policy.lambda_policy.arn
  role       = aws_iam_role.lambda_role.name
}

# Lambda function
resource "aws_lambda_function" "s3_lambda" {
  function_name = "Lambda-function"
  runtime       = "python3.8"
  handler       = "index.lambda_handler"
  role          = aws_iam_role.lambda_role.arn

  filename         = "../lambda_function.zip"
  source_code_hash = filebase64sha256("../lambda_function.zip")
}

# S3 Event Notification -> Lambda
resource "aws_s3_bucket_notification" "s3_lambda_trigger" {
  bucket = aws_s3_bucket.my_bucket.id  # Updated to use my_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_lambda.arn
    events             = ["s3:ObjectCreated:*"]
  } 
}

# Allow S3 to invoke Lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.my_bucket.arn  # Updated to use my_bucket.arn
}
