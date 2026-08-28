# RAG Chatbot MVP — Bedrock + S3 Vectors + WebSocket

A serverless chatbot that answers questions **only** within a declared knowledge domain (trekking routes in Bolivia, used as the sample dataset), built entirely with Infrastructure as Code on a near-zero budget.

## Architecture

```
CLI client (WebSocket)
        │  wss://.../prod
        ▼
API Gateway WebSocket ($connect / $disconnect / sendMessage)
        │
        ▼
Lambda "chat" (Node.js)  ──────────────►  Bedrock Guardrail (topic policy + contextual grounding)
        │                                          │
        ▼                                          ▼
Bedrock Knowledge Base  ────────────►  Nova Micro (generates the final answer)
        │
        ▼
S3 Vectors (embeddings)  ◄── S3 bucket (docs/*.md)  ◄── Lambda "ingest" (manual, idempotent)
```

Every response is generated **synchronously within a single Lambda invocation** — there is no connection table and no background job, per the design constraint of this exercise.

## Why these specific choices

- **S3 Vectors instead of OpenSearch Serverless**: OpenSearch Serverless has a fixed cost floor of roughly $700/month regardless of usage. S3 Vectors is genuinely pay-per-use with no floor, which is the only way to keep this MVP close to $0.
- **Amazon Nova Micro** as the generation model: the cheapest usable Bedrock model for grounded RAG answers.
- **No DynamoDB connection table**: the chat Lambda receives the `connectionId` directly in the event context and posts the answer back via the API Gateway Management API before the invocation ends — nothing needs to persist between messages.

## Prerequisites

- Terraform >= 1.9
- AWS CLI >= 2.x, configured with credentials for an IAM user (never the root user) that has sufficient permissions to create the resources below
- Node.js + npm (to install the Lambda dependencies before packaging)
- An AWS account with a valid, verified payment method and currency configured under **Billing → Payment preferences**

## One-time AWS console setup

Some steps are deliberately manual and happen once per account, before any `terraform apply`:

1. **IAM user for Terraform**: IAM → Users → Create user (e.g. `terraform-admin`), no console access, `AdministratorAccess` policy attached (fine for an MVP; scope it down for production).
2. **Access keys**: on that user → Security credentials → Create access key → CLI use case.
3. **Configure the CLI locally**:
   ```bash
   aws configure
   # Access Key ID / Secret Access Key from step 2
   # Default region: us-east-1
   # Default output format: json
   ```
   Verify with `aws sts get-caller-identity`.
4. **Bedrock model access**: AWS retired the old "Model access" screen. Serverless foundation models (Nova, Titan) are now enabled automatically on first invocation — no manual step needed in the normal case.
5. **AWS Budget**: set up a low-threshold budget (e.g. $2–5) as a spend alarm before touching any billable resource. This is a notification only, not a balance.

### If Bedrock returns `ValidationException: Operation not allowed`

This is a known account-level restriction on some newly created AWS accounts, unrelated to IAM permissions or payment method. It affects **every** Bedrock model, not just one.

Fix: open a free support case — **Support → Create a case → Case type: "Account and billing" → Service: "Account Activation" → Category: "Bedrock Allowlisting"**. Typical resolution time is a few hours under the Basic (free) support plan. There is no self-service fix; retrying `InvokeModel` will not resolve it.

## Deploy the infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Outputs after a successful apply:

```
websocket_url       = "wss://xxxxx.execute-api.us-east-1.amazonaws.com/prod"
ingest_lambda_name  = "rag-mvp-ingest"
knowledge_base_id   = "..."
data_source_id      = "..."
guardrail_id        = "..."
docs_bucket_name    = "rag-mvp-docs-<account-id>"
```

## Quick reference — common commands

A cheat sheet of the commands you'll use most often once the stack is deployed.

### Upload or refresh documents in S3

Documents are normally managed through Terraform (`docs/*.md` → uploaded automatically on `terraform apply`). Two ways to push a change:

**Option A — through Terraform (recommended, keeps state in sync):**

```bash
# after editing/adding a .md file under docs/
cd terraform
terraform apply
```

Terraform detects the changed file hash and re-uploads only what changed.

**Option B — direct S3 sync (faster iteration while drafting content, bypasses Terraform state):**

```bash
aws s3 sync ../docs s3://rag-mvp-docs-<account-id> --exclude "*" --include "*.md"
```

If you use Option B, run `terraform apply` afterwards at least once so Terraform's state matches reality (otherwise the next `apply` may try to "fix" files it thinks are out of sync).

Either way, **uploading a file does not re-index it** — you still need to trigger ingestion (next section) for the Knowledge Base to actually read the new content.

### Trigger (or refresh) the Knowledge Base ingestion

```bash
aws lambda invoke \
  --function-name rag-mvp-ingest \
  --cli-binary-format raw-in-base64-out \
  --payload "{}" \
  response.json

cat response.json
```

Check on a running job:

```bash
aws bedrock-agent list-ingestion-jobs \
  --knowledge-base-id <knowledge_base_id> \
  --data-source-id <data_source_id> \
  --max-results 5
```

Get details on a specific job (status, failure reasons if any):

```bash
aws bedrock-agent get-ingestion-job \
  --knowledge-base-id <knowledge_base_id> \
  --data-source-id <data_source_id> \
  --ingestion-job-id <ingestion_job_id>
```

### Test the WebSocket connection

**Option A — the bundled Node.js CLI client** (handles the `action` envelope and prints citations for you):

```bash
cd client
npm install
node chat_client.js "wss://xxxxx.execute-api.us-east-1.amazonaws.com/prod"
```

Example session:

```
Connecting to wss://xxxxx.execute-api.us-east-1.amazonaws.com/prod ...
Connected. Type your question (or 'exit' to quit).

You: How long does the Choro Trail take?
Bot: The Choro Trail typically takes 3 to 4 days, covering roughly 70 km...
  Sources:
   - s3://rag-mvp-docs-.../01-routes-near-la-paz.md

You: Give me a pizza recipe
Bot: Sorry, I can only answer questions about trekking and hiking routes in Bolivia...

You: exit
```

**Option B — `wscat`, for quick manual testing without any custom client:**

```bash
npm install -g wscat
wscat -c "wss://xxxxx.execute-api.us-east-1.amazonaws.com/prod"
```

Once connected, send a raw JSON message (the `action` field is what routes it to the `sendMessage` route):

```json
{ "action": "sendMessage", "message": "How long does the Choro Trail take?" }
```

The response arrives as a JSON message on the same connection:

```json
{
  "answer": "The Choro Trail typically takes 3 to 4 days...",
  "citations": ["s3://rag-mvp-docs-.../01-routes-near-la-paz.md"]
}
```

Type `Ctrl+C` to close the connection.

**Option C — Postman**, if you prefer a GUI: create a new WebSocket request, paste the `wss://` URL, connect, then send the same JSON body shown above in the message pane.

### Inspect Lambda logs while testing

Useful when a question doesn't behave as expected (e.g. checking whether the guardrail actually fired, or catching a runtime error):

```bash
aws logs tail /aws/lambda/rag-mvp-chat --since 10m --follow
```

Run this in a separate terminal while you send messages through `wscat` or the CLI client — you'll see each invocation's `console.log`/`console.error` output in near real time.

## Typical workflow after deployment

Once `terraform apply` has run successfully, the day-to-day loop looks like this:

1. Edit or add a `.md` file under `docs/`.
2. Re-upload it (`terraform apply`, or `aws s3 sync` — see **Quick reference** above).
3. Trigger ingestion (`aws lambda invoke --function-name rag-mvp-ingest ...`).
4. Wait 1–5 minutes, then confirm the job finished (`list-ingestion-jobs` / `get-ingestion-job`).
5. Connect with `wscat` or the Node.js client and ask a question that should now be answerable from the new content.

For the demo requirement, run through both of these to show the guardrail working correctly:

**In-domain** (should answer using the ingested documents):

```json
{ "action": "sendMessage", "message": "How long does the Choro Trail take?" }
```

**Out-of-domain** (should trigger the guardrail's topic-policy rejection instead of a hallucinated answer):

```json
{ "action": "sendMessage", "message": "Give me a pizza recipe" }
```

## Guardrail configuration

Two independent controls are applied around every generated answer:

- **Topic policy** (`DENY` type): blocks input questions unrelated to the declared domain, using a short natural-language definition plus example phrases.
- **Contextual grounding**: two separate filters —
  - `GROUNDING` (threshold 0.6): rejects answers not actually backed by the retrieved document chunks (hallucination guard).
  - `RELEVANCE` (threshold 0.6): rejects answers that don't address the question actually asked, even if factually accurate.
- **Content filters** (`HATE`, `INSULTS`, `SEXUAL`, `VIOLENCE`, `MISCONDUCT`, `PROMPT_ATTACK`), all at `MEDIUM` strength, as a general-purpose safety net independent of the domain restriction.

Guardrail versions are immutable once published — any configuration change forces Terraform to destroy and recreate `aws_bedrock_guardrail_version`, incrementing the version number.

## Project structure

```
rag-chatbot-mvp/
├── terraform/
│   ├── versions.tf          # Terraform + provider version constraints
│   ├── provider.tf          # AWS provider, region, default tags
│   ├── variables.tf         # project-wide configurable values
│   ├── s3_docs.tf           # source documents bucket
│   ├── s3_vectors.tf        # S3 Vectors bucket + index
│   ├── iam_bedrock_kb.tf    # IAM role Bedrock uses to read S3 / write vectors
│   ├── bedrock_kb.tf        # Knowledge Base + Data Source
│   ├── guardrail.tf         # topic policy + grounding + content filters
│   ├── iam_lambda.tf        # IAM roles for both Lambdas
│   ├── lambda.tf            # packaging + Lambda functions
│   ├── websocket_api.tf     # API Gateway WebSocket, routes, permissions
│   └── outputs.tf
├── lambda/
│   ├── ingest/               # manual, idempotent Knowledge Base sync trigger
│   └── chat/                 # WebSocket handler: RAG query + guardrail
├── docs/                     # source markdown documents for the Knowledge Base
├── client/                   # Node.js CLI test client
└── README.md
```

## Cost notes

- **Bedrock is never free-tier**, in any AWS account state — every embedding and inference call is billed from the first token. For this MVP's realistic usage, total cost is a few cents.
- Lambda, API Gateway, and S3 either fall under Always Free quotas or bill fractions of a cent at this volume.
- Nothing in this stack has a fixed monthly floor — every component is genuinely pay-per-use.

## Clean up

```bash
cd terraform
terraform destroy
```

Removes every resource: Lambdas, API Gateway, Knowledge Base, Guardrail, both S3 buckets (`force_destroy = true` allows deleting non-empty buckets), and IAM roles.
