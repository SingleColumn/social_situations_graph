import Anthropic from "@anthropic-ai/sdk";
import dotenv from "dotenv";
import { Interpretation, interpretationSchema } from "./types.js";

dotenv.config({ override: true });
let resolvedModelId: string | null = null;

function getApiKey(): string {
  return (process.env.ANTHROPIC_API_KEY || "").trim();
}

async function resolveModelId(client: Anthropic): Promise<string> {
  const explicitModel = (process.env.ANTHROPIC_MODEL || "").trim();
  if (explicitModel) {
    return explicitModel;
  }

  if (resolvedModelId) {
    return resolvedModelId;
  }

  const fallbackModel = "claude-3-5-sonnet-latest";
  try {
    const response = await client.models.list();
    const ids = response.data.map((model) => model.id).filter((id): id is string => Boolean(id));

    const prioritized =
      ids.find((id) => id.includes("sonnet")) ||
      ids.find((id) => id.includes("haiku")) ||
      ids[0];

    resolvedModelId = prioritized || fallbackModel;
    return resolvedModelId;
  } catch {
    resolvedModelId = fallbackModel;
    return resolvedModelId;
  }
}

export function hasAnthropicConfigured(): boolean {
  return Boolean(getApiKey());
}

function extractJsonBlock(text: string): string {
  const fenced = text.match(/```json\s*([\s\S]*?)\s*```/i);
  if (fenced?.[1]) return fenced[1].trim();
  return text.trim();
}

function getClient(): Anthropic {
  const apiKey = getApiKey();
  if (!apiKey) {
    throw new Error("ANTHROPIC_API_KEY is not set.");
  }
  return new Anthropic({ apiKey });
}

export async function summarizeInterpretations(params: {
  situation: string;
  templateUsed: string;
  graphRows: unknown[];
}): Promise<Interpretation[]> {
  if (!hasAnthropicConfigured()) {
    return [];
  }

  const client = getClient();
  const model = await resolveModelId(client);
  const prompt = `
You are helping interpret social situations.
Return JSON only in this shape:
{"interpretations":[{"title":"string","confidence":0.0,"rationale":"string"}]}

Rules:
- Provide 1 to 3 interpretations.
- confidence must be 0..1
- Use graph evidence and mention uncertainty when needed.

Situation:
${params.situation}

Template used:
${params.templateUsed}

Graph rows:
${JSON.stringify(params.graphRows, null, 2)}
`;

  const response = await client.messages.create({
    model,
    max_tokens: 600,
    temperature: 0.2,
    messages: [{ role: "user", content: prompt }]
  });

  const text = response.content
    .filter((item) => item.type === "text")
    .map((item) => item.text)
    .join("\n")
    .trim();

  const parsed = JSON.parse(extractJsonBlock(text)) as { interpretations?: unknown[] };
  const interpretations = Array.isArray(parsed.interpretations) ? parsed.interpretations : [];
  return interpretations.map((item) => interpretationSchema.parse(item));
}
