output "websocket_url" {
  description = "WebSocket URL for the chat client"
  value       = aws_apigatewayv2_stage.prod.invoke_url
}

output "ingest_lambda_name" {
  description = "Name of the ingest Lambda (for manual invocation)"
  value       = aws_lambda_function.ingest.function_name
}

output "knowledge_base_id" {
  value = aws_bedrockagent_knowledge_base.main.id
}

output "data_source_id" {
  value = aws_bedrockagent_data_source.docs.data_source_id
}

output "docs_bucket_name" {
  value = aws_s3_bucket.docs.bucket
}

output "guardrail_id" {
  value = aws_bedrock_guardrail.topic_guard.guardrail_id
}
