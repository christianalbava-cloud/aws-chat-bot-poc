import boto3
import json

client = boto3.client("bedrock-runtime", region_name="us-east-1")

request_body = {
    "schemaVersion": "messages-v1",
    "messages": [
        {
            "role": "user",
            "content": [{"text": "hola"}]
        }
    ],
    "inferenceConfig": {
        "maxTokens": 300,
        "temperature": 0.7,
        "topP": 0.9,
        "topK": 20
    }
}

try:
    response = client.invoke_model(
        modelId="amazon.nova-micro-v1:0",
        body=json.dumps(request_body)
    )
    response_body = json.loads(response["body"].read())
    print(json.dumps(response_body, indent=2, ensure_ascii=False))
except Exception as e:
    print("ERROR TYPE:", type(e).__name__)
    print("ERROR:", e)