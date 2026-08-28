data "aws_iam_policy_document" "lambda_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# ---------- Rol Lambda de ingesta ----------
resource "aws_iam_role" "ingest_lambda" {
  name               = "${var.project_name}-ingest-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role_policy_attachment" "ingest_lambda_logs" {
  role       = aws_iam_role.ingest_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "ingest_lambda_permissions" {
  statement {
    sid    = "IngestionJobControl"
    effect = "Allow"
    actions = [
      "bedrock:StartIngestionJob",
      "bedrock:ListIngestionJobs",
      "bedrock:GetIngestionJob",
    ]
    resources = [aws_bedrockagent_knowledge_base.main.arn]
  }
}

resource "aws_iam_role_policy" "ingest_lambda_permissions" {
  name   = "${var.project_name}-ingest-lambda-permissions"
  role   = aws_iam_role.ingest_lambda.id
  policy = data.aws_iam_policy_document.ingest_lambda_permissions.json
}

# ---------- Rol Lambda de chat ----------
resource "aws_iam_role" "chat_lambda" {
  name               = "${var.project_name}-chat-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role_policy_attachment" "chat_lambda_logs" {
  role       = aws_iam_role.chat_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "chat_lambda_permissions" {
  statement {
    sid    = "RagQuery"
    effect = "Allow"
    actions = [
      "bedrock:RetrieveAndGenerate",
      "bedrock:Retrieve",
    ]
    resources = [aws_bedrockagent_knowledge_base.main.arn]
  }

  statement {
    sid       = "InvokeChatModel"
    effect    = "Allow"
    actions   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
    resources = ["arn:aws:bedrock:${var.aws_region}::foundation-model/${var.chat_model_id}"]
  }

  statement {
    sid       = "ApplyGuardrail"
    effect    = "Allow"
    actions   = ["bedrock:ApplyGuardrail"]
    resources = [aws_bedrock_guardrail.topic_guard.guardrail_arn]
  }

  statement {
    sid       = "PostToWebSocketConnection"
    effect    = "Allow"
    actions   = ["execute-api:ManageConnections"]
    resources = ["arn:aws:execute-api:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${aws_apigatewayv2_api.chat.id}/*"]
  }
}

resource "aws_iam_role_policy" "chat_lambda_permissions" {
  name   = "${var.project_name}-chat-lambda-permissions"
  role   = aws_iam_role.chat_lambda.id
  policy = data.aws_iam_policy_document.chat_lambda_permissions.json
}
