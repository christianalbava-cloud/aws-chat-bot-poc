const {
  BedrockAgentClient,
  ListIngestionJobsCommand,
  StartIngestionJobCommand,
} = require("@aws-sdk/client-bedrock-agent");

const client = new BedrockAgentClient();

const KB_ID = process.env.KNOWLEDGE_BASE_ID;
const DS_ID = process.env.DATA_SOURCE_ID;

const IN_PROGRESS_STATUSES = new Set(["STARTING", "IN_PROGRESS"]);

exports.handler = async (event) => {
  const existing = await client.send(
    new ListIngestionJobsCommand({
      knowledgeBaseId: KB_ID,
      dataSourceId: DS_ID,
      maxResults: 10,
    })
  );

  const running = (existing.ingestionJobSummaries || []).find((job) =>
    IN_PROGRESS_STATUSES.has(job.status)
  );

  if (running) {
    return respond(200, {
      message: "An ingestion job is already running, not starting a new one.",
      ingestionJobId: running.ingestionJobId,
      status: running.status,
    });
  }

  const started = await client.send(
    new StartIngestionJobCommand({
      knowledgeBaseId: KB_ID,
      dataSourceId: DS_ID,
      description: "Manual sync triggered by ingest lambda",
    })
  );

  const job = started.ingestionJob;
  return respond(200, {
    message: "Ingestion job started.",
    ingestionJobId: job.ingestionJobId,
    status: job.status,
  });
};

function respond(statusCode, bodyObj) {
  const result = { statusCode, body: JSON.stringify(bodyObj) };
  console.log(JSON.stringify(result));
  return result;
}