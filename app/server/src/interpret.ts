import { summarizeInterpretations } from "./anthropic.js";
import { extractTerm, queryTemplates, selectTemplate } from "./queries.js";
import { runCypher } from "./neo4j.js";
import { InterpretResponse, Interpretation } from "./types.js";

function toNumber(value: unknown): number | undefined {
  if (typeof value === "number") return value;
  if (value && typeof value === "object" && "toNumber" in value) {
    const maybe = value as { toNumber?: () => number };
    if (typeof maybe.toNumber === "function") return maybe.toNumber();
  }
  return undefined;
}

function fallbackInterpretations(rows: Record<string, unknown>[]): Interpretation[] {
  const scores = new Map<string, { score: number; reasons: string[] }>();

  for (const row of rows) {
    const preds = Array.isArray(row.predictions) ? row.predictions : [];
    for (const pred of preds) {
      if (!pred || typeof pred !== "object") continue;
      const meaning = String((pred as Record<string, unknown>).meaning || "").trim();
      const probability = toNumber((pred as Record<string, unknown>).probability) ?? 0.45;
      if (!meaning) continue;

      const existing = scores.get(meaning) || { score: 0, reasons: [] };
      existing.score = Math.max(existing.score, probability);
      if (row.situationId) {
        existing.reasons.push(`Seen in ${String(row.situationId)}.`);
      }
      scores.set(meaning, existing);
    }
  }

  return [...scores.entries()]
    .sort((a, b) => b[1].score - a[1].score)
    .slice(0, 3)
    .map(([title, value]) => ({
      title,
      confidence: Math.max(0.1, Math.min(1, value.score)),
      rationale: value.reasons[0] || "Based on closest pattern matches in the graph."
    }));
}

export async function interpretSituation(situation: string): Promise<InterpretResponse> {
  const primaryTemplate = selectTemplate(situation);
  const fallbackTemplate = queryTemplates[2];
  const templateOrder = [primaryTemplate, ...queryTemplates.filter((t) => t.id !== primaryTemplate.id && t.id !== fallbackTemplate.id), fallbackTemplate];
  const term = extractTerm(situation);
  let graphRows: Record<string, unknown>[] = [];
  let usedTemplateId = primaryTemplate.id;

  for (const template of templateOrder) {
    const rows = await runCypher<Record<string, unknown>>(template.cypher, { term });
    if (rows.length > 0) {
      graphRows = rows;
      usedTemplateId = template.id;
      break;
    }
  }

  const warnings: string[] = [];
  let interpretations: Interpretation[] = [];

  try {
    interpretations = await summarizeInterpretations({
      situation,
      templateUsed: usedTemplateId,
      graphRows
    });
  } catch (err) {
    const details = err instanceof Error ? err.message : String(err);
    warnings.push(`Anthropic summarization unavailable (${details}). Returned deterministic fallback result.`);
  }

  if (!interpretations.length) {
    interpretations = fallbackInterpretations(graphRows);
  }

  return {
    interpretations,
    templateUsed: usedTemplateId,
    warnings
  };
}
