# How interpretation works

This document explains what happens when a user submits a situation to `POST /api/interpret`.

---

## Overview

The LLM does not query the graph. The app queries Neo4j first, then passes the results to Claude to synthesize into human-readable interpretations.

```
User input
  → term extraction + template selection   (queries.ts)
  → Neo4j query                            (neo4j.ts)
  → Claude summarization                   (anthropic.ts)
  → ranked interpretations returned
```

---

## Step 1 — Term extraction (`queries.ts: extractTerm`)

A search term is pulled from the input:
- If the input contains quoted text (e.g. `"nice painting"`), that quoted text is used.
- Otherwise, the first 8 words are used.

---

## Step 2 — Template selection (`queries.ts: selectTemplate`)

The input is scanned for keywords to pick the most appropriate Cypher query:

| Template | Trigger keywords | Matches on |
|---|---|---|
| `statement_text` | said, told, statement, `"` | `Statement.text` |
| `tone_expression_context` | tone, expression, context, eye, smile | `Context.value` |
| `fallback_signal_pattern` | (none of the above) | all `SituationSignal` → `Pattern` chains |

Templates are tried in order until one returns rows. If all return empty, the fallback runs unconditionally.

---

## Step 3 — Neo4j query (`interpret.ts: interpretSituation`)

Each template traverses the graph along the inference channel:

```
Situation → HAS_SIGNAL → SituationSignal → INSTANCE_OF → SignalType
                                                              ↑
                                               Pattern → REQUIRES
                                                              ↓
                                               Pattern → PREDICTS → IntendedMeaning
```

The query returns per-situation rows containing: matched signals, matched patterns, and predictions (intended meaning + probability).

---

## Step 4 — Claude summarization (`anthropic.ts: summarizeInterpretations`)

The raw graph rows are sent to Claude along with the original situation text and which template was used. Claude is asked to return 1–3 interpretations as JSON:

```json
{"interpretations": [{"title": "string", "confidence": 0.0, "rationale": "string"}]}
```

Claude uses the graph evidence to ground its response and is instructed to mention uncertainty where relevant. The response is parsed and validated with Zod.

---

## Fallback

If Claude is unavailable, `fallbackInterpretations()` generates a deterministic result directly from the graph rows: it ranks `IntendedMeaning` values by their `PREDICTS` probability, deduplicates, and returns the top 3.
