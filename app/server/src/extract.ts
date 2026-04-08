import Anthropic from "@anthropic-ai/sdk";
import { z } from "zod";
import dotenv from "dotenv";

dotenv.config({ override: true });

// The complete SignalType vocabulary from the graph spec.
// Update this list if new SignalType nodes are added to the graph.
const SIGNAL_VOCABULARY = [
  { kind: "tone",           valueId: "dry_tone" },
  { kind: "tone",           valueId: "enthusiastic_tone" },
  { kind: "expression",     valueId: "eye_roll" },
  { kind: "expression",     valueId: "awe" },
  { kind: "context",        valueId: "They are looking at my painting" },
  { kind: "literal_meaning", valueId: "praise" },
] as const;

const extractedSignalsSchema = z.object({
  signals: z.array(z.object({
    kind: z.string(),
    valueId: z.string(),
  })),
  speakerName: z.string().optional(),
  statementText: z.string().optional(),
});

export type ExtractedSignals = z.infer<typeof extractedSignalsSchema>;

function getClient(): Anthropic {
  const apiKey = (process.env.ANTHROPIC_API_KEY || "").trim();
  if (!apiKey) throw new Error("ANTHROPIC_API_KEY is not set.");
  return new Anthropic({ apiKey });
}

function extractJsonBlock(text: string): string {
  const fenced = text.match(/```json\s*([\s\S]*?)\s*```/i);
  if (fenced?.[1]) return fenced[1].trim();
  return text.trim();
}

export async function extractSignalTypes(situation: string): Promise<ExtractedSignals> {
  const client = getClient();

  const vocabularyList = SIGNAL_VOCABULARY
    .map(s => `  { kind: "${s.kind}", valueId: "${s.valueId}" }`)
    .join("\n");

  const prompt = `Extract observable social cues from this situation. Only use valueIds from the vocabulary below.

Vocabulary:
${vocabularyList}

Return JSON only:
{ "signals": [{ "kind": "string", "valueId": "string" }], "speakerName": "string", "statementText": "string" }

Omit speakerName or statementText if not present. Include one signal per observable cue found.

Situation: ${situation}`;

  const response = await client.messages.create({
    model: (process.env.ANTHROPIC_MODEL || "claude-sonnet-4-6").trim(),
    max_tokens: 300,
    temperature: 0,
    messages: [{ role: "user", content: prompt }],
  });

  const text = response.content
    .filter(item => item.type === "text")
    .map(item => item.text)
    .join("\n")
    .trim();

  const parsed = JSON.parse(extractJsonBlock(text));
  return extractedSignalsSchema.parse(parsed);
}
