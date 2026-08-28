const {
  BedrockAgentRuntimeClient,
  RetrieveAndGenerateCommand,
} = require("@aws-sdk/client-bedrock-agent-runtime");
const {
  ApiGatewayManagementApiClient,
  PostToConnectionCommand,
} = require("@aws-sdk/client-apigatewaymanagementapi");

const bedrockClient = new BedrockAgentRuntimeClient();

const KB_ID = process.env.KNOWLEDGE_BASE_ID;
const GUARDRAIL_ID = process.env.GUARDRAIL_ID;
const GUARDRAIL_VERSION = process.env.GUARDRAIL_VERSION;
const MODEL_ARN = process.env.MODEL_ARN;

exports.handler = async (event) => {
  const routeKey = event.requestContext.routeKey;

  if (routeKey === "$connect" || routeKey === "$disconnect") {
    return { statusCode: 200 };
  }

  if (routeKey === "sendMessage") {
    return handleMessage(event);
  }

  return { statusCode: 400, body: "Unknown route" };
};

async function handleMessage(event) {
  const { connectionId, domainName, stage } = event.requestContext;

  const apiGwClient = new ApiGatewayManagementApiClient({
    endpoint: `https://${domainName}/${stage}`,
  });

  try {
    const body = JSON.parse(event.body || "{}");
    const question = (body.message || "").trim();

    if (!question) {
      await post(apiGwClient, connectionId, { error: "Empty message" });
      return { statusCode: 200 };
    }

    const { answer, citations } = await ragQuery(question);
    await post(apiGwClient, connectionId, { answer, citations });
    return { statusCode: 200 };
  } catch (err) {
    console.error("ERROR:", err);
    try {
      await post(apiGwClient, connectionId, {
        error: "An error occurred while processing your message.",
      });
    } catch (_) {
      // if we can't even post the error, there's nothing more to do
    }
    return { statusCode: 200 };
  }
}

async function ragQuery(question) {
  const command = new RetrieveAndGenerateCommand({
    input: { text: question },
    retrieveAndGenerateConfiguration: {
      type: "KNOWLEDGE_BASE",
      knowledgeBaseConfiguration: {
        knowledgeBaseId: KB_ID,
        modelArn: MODEL_ARN,
        generationConfiguration: {
          guardrailConfiguration: {
            guardrailId: GUARDRAIL_ID,
            guardrailVersion: GUARDRAIL_VERSION,
          },
        },
      },
    },
  });

  const response = await bedrockClient.send(command);
  const answer = response.output?.text || "";

  const citations = [];
  for (const citation of response.citations || []) {
    for (const ref of citation.retrievedReferences || []) {
      const uri = ref.location?.s3Location?.uri;
      if (uri && !citations.includes(uri)) {
        citations.push(uri);
      }
    }
  }

  return { answer, citations };
}

async function post(apiGwClient, connectionId, payload) {
  await apiGwClient.send(
    new PostToConnectionCommand({
      ConnectionId: connectionId,
      Data: Buffer.from(JSON.stringify(payload)),
    })
  );
}