resource "aws_bedrock_guardrail" "topic_guard" {
  name                      = "${var.project_name}-guardrail"
  description               = "Restricts the chatbot to the domain: ${var.kb_topic}"
  blocked_input_messaging   = "Sorry, I can only answer questions about ${var.kb_topic}. Do you have a question on that topic?"
  blocked_outputs_messaging = "Sorry, I can only answer questions about ${var.kb_topic}. Do you have a question on that topic?"

  topic_policy_config {
    topics_config {
      name       = "off-topic-subjects"
      type       = "DENY"
      definition = "Questions or requests unrelated to ${var.kb_topic}, such as programming, recipes, politics, or general topics."
      examples = [
        "What is the capital of France?",
        "Write me a function in Python",
        "Give me a pizza recipe",
        "What do you think about current politics?",
      ]
    }
  }

  contextual_grounding_policy_config {
    filters_config {
      type      = "GROUNDING"
      threshold = 0.6
    }
    filters_config {
      type      = "RELEVANCE"
      threshold = 0.6
    }
  }

  content_policy_config {
    filters_config {
      type            = "HATE"
      input_strength  = "MEDIUM"
      output_strength = "MEDIUM"
    }
    filters_config {
      type            = "INSULTS"
      input_strength  = "MEDIUM"
      output_strength = "MEDIUM"
    }
    filters_config {
      type            = "SEXUAL"
      input_strength  = "MEDIUM"
      output_strength = "MEDIUM"
    }
    filters_config {
      type            = "VIOLENCE"
      input_strength  = "MEDIUM"
      output_strength = "MEDIUM"
    }
    filters_config {
      type            = "MISCONDUCT"
      input_strength  = "MEDIUM"
      output_strength = "MEDIUM"
    }
    filters_config {
      type            = "PROMPT_ATTACK"
      input_strength  = "MEDIUM"
      output_strength = "NONE"
    }
  }
}

resource "aws_bedrock_guardrail_version" "topic_guard" {
  guardrail_arn = aws_bedrock_guardrail.topic_guard.guardrail_arn
  description   = "Initial guardrail version for the MVP"
}
