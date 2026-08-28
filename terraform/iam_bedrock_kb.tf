data "aws_iam_policy_document" "kb_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "kb_role" {
  name               = "${var.project_name}-kb-role"
  assume_role_policy = data.aws_iam_policy_document.kb_trust.json
}

data "aws_iam_policy_document" "kb_permissions" {
  statement {
    sid       = "S3ReadDocs"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [aws_s3_bucket.docs.arn, "${aws_s3_bucket.docs.arn}/*"]
  }

  statement {
    sid    = "S3VectorsAccess"
    effect = "Allow"
    actions = [
      "s3vectors:GetVectors",
      "s3vectors:PutVectors",
      "s3vectors:QueryVectors",
      "s3vectors:DeleteVectors",
      "s3vectors:GetIndex",
      "s3vectors:ListIndexes",
      "s3vectors:GetVectorBucket",
    ]
    resources = [
      aws_s3vectors_vector_bucket.kb.vector_bucket_arn,
      aws_s3vectors_index.kb.index_arn,
    ]
  }

  statement {
    sid       = "InvokeEmbeddingModel"
    effect    = "Allow"
    actions   = ["bedrock:InvokeModel"]
    resources = ["arn:aws:bedrock:${var.aws_region}::foundation-model/${var.embedding_model_id}"]
  }
}

resource "aws_iam_role_policy" "kb_permissions" {
  name   = "${var.project_name}-kb-permissions"
  role   = aws_iam_role.kb_role.id
  policy = data.aws_iam_policy_document.kb_permissions.json
}
