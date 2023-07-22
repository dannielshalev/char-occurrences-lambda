provider "aws" {
  region = "us-east-1"  # Change to your desired region
}

# DynamoDB Table
resource "aws_dynamodb_table" "occurrences_table" {
  name         = "OccurrencesTable"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute {
    name = "id"
    type = "S"
  }
}

# Lambda Execution Role
resource "aws_iam_role" "lambda_execution_role" {
  name = "LambdaExecutionRole"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Lambda Functions
resource "aws_lambda_function" "calculate_occurrences_lambda" {
  filename      = "./lambdas/calculate_occurrences_lambda.zip"
  function_name = "CalculateOccurrencesLambda"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.8"

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.occurrences_table.name
    }
  }
}

resource "aws_lambda_function" "read_result_lambda" {
  filename      = "./lambdas/read_result_lambda.zip"
  function_name = "ReadResultLambda"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.8"

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.occurrences_table.name
    }
  }
}

# API Gateway
resource "aws_api_gateway_rest_api" "api_gateway" {
  name        = "MyApiGateway"
  description = "API Gateway for calculating number of occurrences"
}

resource "aws_api_gateway_resource" "calculate_occurrences_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "calculate-number-of-occurrences"
}

resource "aws_api_gateway_resource" "get_occurrences_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "get-number-of-occurrences"
}

resource "aws_api_gateway_method" "calculate_occurrences_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.calculate_occurrences_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "get_occurrences_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.get_occurrences_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "calculate_occurrences_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.calculate_occurrences_resource.id
  http_method             = aws_api_gateway_method.calculate_occurrences_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.calculate_occurrences_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "get_occurrences_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.get_occurrences_resource.id
  http_method             = aws_api_gateway_method.get_occurrences_method.http_method
  integration_http_method = "GET"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.read_result_lambda.invoke_arn
}

resource "aws_api_gateway_method_response" "calculate_occurrences_method_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.calculate_occurrences_resource.id
  http_method = aws_api_gateway_method.calculate_occurrences_method.http_method
  status_code = "200"
}

resource "aws_api_gateway_method_response" "get_occurrences_method_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.get_occurrences_resource.id
  http_method = aws_api_gateway_method.get_occurrences_method.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "calculate_occurrences_integration_response" {
  rest_api_id        = aws_api_gateway_rest_api.api_gateway.id
  resource_id        = aws_api_gateway_resource.calculate_occurrences_resource.id
  http_method        = aws_api_gateway_method.calculate_occurrences_method.http_method
  status_code        = aws_api_gateway_method_response.calculate_occurrences_method_response.status_code
  response_templates = {
    "application/json" = jsonencode({
      "id" = "$input.path('$.id')"
    })
  }
}

resource "aws_api_gateway_integration_response" "get_occurrences_integration_response" {
  rest_api_id        = aws_api_gateway_rest_api.api_gateway.id
  resource_id        = aws_api_gateway_resource.get_occurrences_resource.id
  http_method        = aws_api_gateway_method.get_occurrences_method.http_method
  status_code        = aws_api_gateway_method_response.get_occurrences_method_response.status_code
  response_templates = {
    "application/json" = ""
  }
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  depends_on  = [
    aws_api_gateway_integration.calculate_occurrences_integration,
    aws_api_gateway_integration.get_occurrences_integration
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "stage" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  deployment_id = aws_api_gateway_deployment.deployment.id
  stage_name    = "dev"
}
