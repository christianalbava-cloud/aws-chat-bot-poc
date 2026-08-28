data "archive_file" "ingest_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/ingest"
  output_path = "${path.module}/../lambda/ingest.zip"
  excludes    = ["package.json", "package-lock.json"]
}

resource "aws_lambda_function" "ingest" {
  function_name    = "${var.project_name}-ingest"
  role             = aws_iam_role.ingest_lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = data.archive_file.ingest_lambda.output_path
  source_code_hash = data.archive_file.ingest_lambda.output_base64sha256
  timeout          = 60

  environment {
    variables = {
      KNOWLEDGE_BASE_ID = aws_bedrockagent_knowledge_base.main.id
      DATA_SOURCE_ID    = aws_bedrockagent_data_source.docs.data_source_id
    }
  }
}

data "archive_file" "chat_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/chat"
  output_path = "${path.module}/../lambda/chat.zip"
  excludes    = ["package.json", "package-lock.json"]
}

resource "aws_lambda_function" "chat" {
  function_name    = "${var.project_name}-chat"
  role             = aws_iam_role.chat_lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = data.archive_file.chat_lambda.output_path
  source_code_hash = data.archive_file.chat_lambda.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      KNOWLEDGE_BASE_ID = aws_bedrockagent_knowledge_base.main.id
      GUARDRAIL_ID      = aws_bedrock_guardrail.topic_guard.guardrail_id
      GUARDRAIL_VERSION = aws_bedrock_guardrail_version.topic_guard.version
      MODEL_ARN         = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.chat_model_id}"
    }
  }
}
