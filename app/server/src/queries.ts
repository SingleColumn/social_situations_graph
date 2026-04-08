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
OPTIONAL MATCH (sit)-[:HAS_SIGNAL]->(sig:SituationSignal)-[:INSTANCE_OF]->(st:SignalType)
OPTIONAL MATCH (p:Pattern)-[:REQUIRES]->(st)
OPTIONAL MATCH (p)-[pred:PREDICTS]->(im:IntendedMeaning)
RETURN sit.situationId AS situationId,
       sit.description AS situationDescription,
       collect(DISTINCT st.valueId) AS matchedSignals,
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
OPTIONAL MATCH (sit)-[:HAS_SIGNAL]->(sig:SituationSignal)-[:INSTANCE_OF]->(st:SignalType)
OPTIONAL MATCH (p:Pattern)-[:REQUIRES]->(st)
OPTIONAL MATCH (p)-[pred:PREDICTS]->(im:IntendedMeaning)
RETURN sit.situationId AS situationId,
       sit.description AS situationDescription,
       stmt.text AS matchedStatement,
       collect(DISTINCT st.valueId) AS matchedSignals,
       collect(DISTINCT p.patternId) AS matchedPatterns,
       collect(DISTINCT {meaning: im.value, probability: pred.probability}) AS predictions
LIMIT 5
`
  },
  {
    id: "fallback_signal_pattern",
    description: "Fallback broad retrieval for likely related patterns",
    cypher: `
MATCH (sit:Situation)-[:HAS_SIGNAL]->(sig:SituationSignal)-[:INSTANCE_OF]->(st:SignalType)
OPTIONAL MATCH (p:Pattern)-[:REQUIRES]->(st)
OPTIONAL MATCH (p)-[pred:PREDICTS]->(im:IntendedMeaning)
RETURN sit.situationId AS situationId,
       sit.description AS situationDescription,
       collect(DISTINCT st.valueId) AS matchedSignals,
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

// Read-only query for scenario preview: finds Pattern + IntendedMeaning nodes
// whose required SignalTypes are fully covered by the provided signal list.
export const previewQuery = `
UNWIND $signals AS sig
MATCH (st:SignalType { kind: sig.kind, valueId: sig.valueId })
WITH collect(st) AS matchedTypes,
     collect({ neoId: elementId(st), kind: st.kind, valueId: st.valueId }) AS matchedSignalData

MATCH (p:Pattern)
WHERE all(req IN [(p)-[:REQUIRES]->(rs) | rs] WHERE req IN matchedTypes)

OPTIONAL MATCH (p)-[pred:PREDICTS]->(im:IntendedMeaning)
OPTIONAL MATCH (p)-[:REQUIRES]->(req_st:SignalType)

RETURN
  matchedSignalData,
  elementId(p)    AS patternNeoId,
  p.patternId     AS patternId,
  p.description   AS patternDescription,
  collect(DISTINCT { neoId: elementId(im), value: im.value, probability: pred.probability }) AS predictions,
  collect(DISTINCT { neoId: elementId(req_st), kind: req_st.kind, valueId: req_st.valueId }) AS requiredSignalTypes
`;

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
