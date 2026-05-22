const MAX_BODY_BYTES = 80_000;
const MAX_PROMPT_CHARS = 50_000;
const PROVIDER_TIMEOUT_MS = 85_000;
const STRUCTURED_MAX_TOKENS = 2200;
const RECEIPT_MAX_TOKENS = 2200;
const TEXT_MAX_TOKENS = 1000;
const STRUCTURED_TOOL_NAME = "return_clearspend_result";
const FINANCE_ACCURACY_RULES = [
  "Accuracy rules:",
  "- The app provides the user's budget, transaction, merchant, category, date, goal, and pace evidence. Treat it as the only source of truth.",
  "- Never invent transactions, merchants, income, categories, dates, goals, percentages, or forecasts that are not supported by the prompt.",
  "- When making a claim, ground it in a specific amount, merchant, category, date range, percentage, or transaction from the prompt.",
  "- If the data is too thin, state the limitation plainly and give the best useful next step from the available evidence.",
  "- Keep outputs short, practical, and non-judgmental. Avoid generic financial advice.",
  "- For forecasts, stay close to app-provided baselines unless a concrete category or merchant pattern justifies an adjustment."
].join("\n");

export default {
  async fetch(request, env) {
    const requestId = crypto.randomUUID();

    try {
      if (request.method === "OPTIONS") {
        return new Response(null, { status: 204 });
      }

      const url = new URL(request.url);
      if (request.method !== "POST" || url.pathname !== "/invoke-llm") {
        return jsonResponse({ error: "Not found", request_id: requestId }, 404);
      }

      const clientId = request.headers.get("X-ClearSpend-Client");

      if (clientId !== env.CLEARSPEND_CLIENT_ID) {
        return jsonResponse({ error: "Unauthorized", request_id: requestId }, 401);
      }

      const contentLength = Number(request.headers.get("content-length") ?? "0");
      if (contentLength > MAX_BODY_BYTES) {
        return jsonResponse({ error: "Request is too large", request_id: requestId }, 413);
      }

      const body = await request.json();
      const prompt = typeof body.prompt === "string" ? body.prompt.trim() : "";
      const responseJsonSchema = body.response_json_schema;

      if (!prompt) {
        return jsonResponse({ error: "Prompt is required", request_id: requestId }, 400);
      }

      if (prompt.length > MAX_PROMPT_CHARS) {
        return jsonResponse({ error: "Prompt is too large", request_id: requestId }, 413);
      }

      const content = await invokeDeepSeek(env, prompt, responseJsonSchema);

      if (!content) {
        return jsonResponse({ error: "Empty AI response", request_id: requestId }, 502);
      }

      return new Response(content.trim(), {
        status: 200,
        headers: {
          "Content-Type": responseJsonSchema ? "application/json; charset=utf-8" : "text/plain; charset=utf-8",
          "X-Request-Id": requestId
        }
      });
    } catch (error) {
      const status = error instanceof HttpError ? error.status : 500;
      const publicMessage = error instanceof HttpError ? error.message : "AI request failed";

      console.error(JSON.stringify({
        request_id: requestId,
        status,
        message: error instanceof Error ? error.message : "Unknown error"
      }));

      return jsonResponse({ error: publicMessage, message: publicMessage, request_id: requestId }, status);
    }
  }
};

async function invokeDeepSeek(env, prompt, responseJsonSchema) {
  const payload = buildPayload(env, prompt, responseJsonSchema, responseJsonSchema ? "tool" : "text");
  const result = await requestDeepSeek(env, payload);

  if (result.content) {
    return result.content;
  }

  console.error(JSON.stringify({
    provider_status: "empty_content",
    finish_reason: result.finishReason ?? "unknown",
    mode: responseJsonSchema ? "tool" : "text"
  }));

  if (responseJsonSchema) {
    const fallbackPayload = buildPayload(env, prompt, responseJsonSchema, "json");
    const fallbackResult = await requestDeepSeek(env, fallbackPayload);
    if (fallbackResult.content) {
      return fallbackResult.content;
    }

    console.error(JSON.stringify({
      provider_status: "empty_content",
      finish_reason: fallbackResult.finishReason ?? "unknown",
      mode: "json"
    }));
  }

  throw new HttpError("AI returned an empty response. Please try again.", 502);
}

function buildPayload(env, prompt, responseJsonSchema, mode) {
  const messages = [
    {
      role: "system",
      content: buildSystemPrompt(responseJsonSchema, mode)
    },
    {
      role: "user",
      content: prompt
    }
  ];

  const payload = {
    model: env.DEEPSEEK_MODEL,
    messages,
    thinking: { type: "disabled" },
    temperature: 0.1,
    top_p: 0.75,
    max_tokens: maxTokensFor(responseJsonSchema)
  };

  if (responseJsonSchema && mode === "tool") {
    payload.tools = [{
      type: "function",
      function: {
        name: STRUCTURED_TOOL_NAME,
        description: "Return the structured ClearSpend result requested by the app.",
        parameters: responseJsonSchema
      }
    }];
    payload.tool_choice = {
      type: "function",
      function: { name: STRUCTURED_TOOL_NAME }
    };
  } else if (responseJsonSchema && mode === "json") {
    payload.response_format = { type: "json_object" };
  }

  return payload;
}

async function requestDeepSeek(env, payload) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort("Provider timed out"), PROVIDER_TIMEOUT_MS);
  let response;

  try {
    response = await fetch(`${env.DEEPSEEK_BASE_URL}/chat/completions`, {
      method: "POST",
      headers: {
        "Accept": "application/json",
        "Authorization": `Bearer ${env.DEEPSEEK_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify(payload),
      signal: controller.signal
    });
  } catch (error) {
    if (error?.name === "AbortError") {
      throw new HttpError("AI request timed out. Please try again.", 504);
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }

  const text = await response.text();
  const data = parseJson(text);

  if (!response.ok) {
    console.error(JSON.stringify({
      provider_status: response.status,
      provider_error: data?.error?.message ?? "DeepSeek request failed"
    }));
    throw new HttpError("Provider request failed", 502);
  }

  return extractContent(data);
}

function extractContent(data) {
  const choice = data?.choices?.[0];
  const message = choice?.message;
  const toolArguments = message?.tool_calls?.[0]?.function?.arguments;
  const content = message?.content;

  if (typeof toolArguments === "string" && toolArguments.trim()) {
    return { content: toolArguments.trim(), finishReason: choice?.finish_reason };
  }

  if (typeof content === "string" && content.trim()) {
    return { content: content.trim(), finishReason: choice?.finish_reason };
  }

  return { content: null, finishReason: choice?.finish_reason };
}

function buildSystemPrompt(responseJsonSchema, mode) {
  if (!responseJsonSchema) {
    return [
      "You are ClearSpend's financial assistant.",
      "Use the user's actual transaction data, budgets, merchants, categories, dates, and goals.",
      "Avoid generic personal-finance advice unless it is tied to a specific number or pattern in the provided data.",
      "Be concise, practical, and accurate.",
      FINANCE_ACCURACY_RULES
    ].join("\n");
  }

  const schemaText = JSON.stringify(responseJsonSchema);
  const isReceiptSchema = schemaText.includes('"items"') && schemaText.includes('"price"');

  if (mode === "tool") {
    return [
      "You are ClearSpend's financial assistant.",
      "Use the user's actual transaction data, budgets, merchants, categories, dates, and goals.",
      "Avoid generic personal-finance advice unless it is tied to a specific number or pattern in the provided data.",
      FINANCE_ACCURACY_RULES,
      isReceiptSchema
        ? "Extract only visible receipt line items and keep merchant/category values concise."
        : "Keep strings concise and specific. Each string should be grounded in provided evidence. Do not add fields that are not in the schema.",
      `Call the ${STRUCTURED_TOOL_NAME} tool with the requested structured result.`
    ].join("\n");
  }

  return [
    "You are ClearSpend's financial assistant.",
    "Use the user's actual transaction data, budgets, merchants, categories, dates, and goals.",
    "Avoid generic personal-finance advice unless it is tied to a specific number or pattern in the provided data.",
    FINANCE_ACCURACY_RULES,
    isReceiptSchema
      ? "Extract only visible receipt line items and keep merchant/category values concise."
      : "Keep the full JSON response concise: short strings, no extra fields, no long explanations. Ground every claim in provided evidence.",
    "Return only valid JSON. Do not include markdown, code fences, or explanatory text.",
    "Use this JSON schema as the required output shape:",
    schemaText
  ].join("\n");
}

function maxTokensFor(responseJsonSchema) {
  if (!responseJsonSchema) {
    return TEXT_MAX_TOKENS;
  }

  const schemaText = JSON.stringify(responseJsonSchema);
  if (schemaText.includes('"items"') && schemaText.includes('"price"')) {
    return RECEIPT_MAX_TOKENS;
  }

  return STRUCTURED_MAX_TOKENS;
}

function jsonResponse(payload, status) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8"
    }
  });
}

function parseJson(text) {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

class HttpError extends Error {
  constructor(message, status) {
    super(message);
    this.status = status;
  }
}
