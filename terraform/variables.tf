variable "aws_region" {
  description = "The AWS us-east-1 region supports S3 Vectors and all the necessary Bedrock models."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short project name, used as a prefix for all resource"
  type        = string
  default     = "rag-mvp"
}

variable "kb_topic" {
  description = "Knowledge base topic/domain, used in the guardrail prompt."
  type        = string
  default     = "Hiking and Trekking Trails in Bolivia"
}

variable "embedding_model_id" {
  description = "Bedrock embedding model used by the Knowledge Base."
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
}

variable "chat_model_id" {
  description = "Bedrock model used to generate responses. Nova Micro is the least expensive."
  type        = string
  default     = "amazon.nova-micro-v1:0"
}

variable "vector_dimension" {
  description = "Vector dimension. It must match the embedding model (Titan v2 = 1024)."
  type        = number
  default     = 1024
}
