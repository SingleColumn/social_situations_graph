export type QueryTemplate = {
  id: string;
  description: string;
  cypher: string;
};

export const queryTemplates: QueryTemplate[] = [
  {
    id: "tone_expression_context",
    description: "Situation includes explicit tone, expression, or context clues",
    cypher: `
MATCH (ctx:Context)
WHERE toLower(ctx.value) CONTAINS toLower($term)
OPTIONAL MATCH (sit:Situation)-[:HAS_CONTEXT]->(ctx)
OPTIONAL MATCH (sit)-[:HAS_SIGNAL]->(sig:Signal)
OPTIONAL MATCH (p:Pattern)-[:REQUIRES]->(sig)
OPTIONAL MATCH (p)-[pred:PREDICTS]->(im:IntendedMeaning)
RETURN sit.situationId AS situationId,
       sit.description AS situationDescription,
       collect(DISTINCT sig.signalId) AS matchedSignals,
       collect(DISTINCT p.patternId) AS matchedPatterns,
       collect(DISTINCT {meaning: im.value, probability: pred.probability}) AS predictions
LIMIT 5
`
  },
  {
    id: "statement_text",
    description: "Situation described by what someone said",
    cypher: `
MATCH (stmt:Statement)
WHERE toLower(stmt.text) CONTAINS toLower($term)
MATCH (sit:Situation)-[:HAS_STATEMENT]->(stmt)
OPTIONAL MATCH (sit)-[:HAS_SIGNAL]->(sig:Signal)
OPTIONAL MATCH (p:Pattern)-[:REQUIRES]->(sig)
OPTIONAL MATCH (p)-[pred:PREDICTS]->(im:IntendedMeaning)
RETURN sit.situationId AS situationId,
       sit.description AS situationDescription,
       stmt.text AS matchedStatement,
       collect(DISTINCT sig.signalId) AS matchedSignals,
       collect(DISTINCT p.patternId) AS matchedPatterns,
       collect(DISTINCT {meaning: im.value, probability: pred.probability}) AS predictions
LIMIT 5
`
  },
  {
    id: "fallback_signal_pattern",
    description: "Fallback broad retrieval for likely related patterns",
    cypher: `
MATCH (sit:Situation)-[:HAS_SIGNAL]->(sig:Signal)
OPTIONAL MATCH (p:Pattern)-[:REQUIRES]->(sig)
OPTIONAL MATCH (p)-[pred:PREDICTS]->(im:IntendedMeaning)
RETURN sit.situationId AS situationId,
       sit.description AS situationDescription,
       collect(DISTINCT sig.signalId) AS matchedSignals,
       collect(DISTINCT p.patternId) AS matchedPatterns,
       collect(DISTINCT {meaning: im.value, probability: pred.probability}) AS predictions
LIMIT 10
`
  }
];

export function selectTemplate(situation: string): QueryTemplate {
  const normalized = situation.toLowerCase();
  const hasStatementCue =
    normalized.includes("said") ||
    normalized.includes("told") ||
    normalized.includes("statement") ||
    normalized.includes("\"");

  const hasContextCue =
    normalized.includes("tone") ||
    normalized.includes("expression") ||
    normalized.includes("context") ||
    normalized.includes("eye") ||
    normalized.includes("smile");

  // Prefer statement matching when both cues are present (e.g. quoted text + eye roll).
  if (hasStatementCue) {
    return queryTemplates[1];
  }

  if (hasContextCue) {
    return queryTemplates[0];
  }

  return queryTemplates[2];
}

export function extractTerm(situation: string): string {
  const cleaned = situation.trim().replace(/\s+/g, " ");
  if (!cleaned) return "";

  // Use quoted statement text when present; this best matches Statement.text.
  const quoted = cleaned.match(/"([^"]{2,})"/);
  if (quoted?.[1]) {
    return quoted[1].trim();
  }

  const words = cleaned.split(" ");
  return words.slice(0, Math.min(8, words.length)).join(" ");
}
