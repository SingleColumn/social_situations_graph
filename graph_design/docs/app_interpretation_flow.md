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

The input is scanned for two classes of keyword to decide which Cypher query to run first:

- **Statement cues** — `said`, `told`, `statement`, or a `"` character. Suggest the input describes what someone said.
- **Context cues** — `tone`, `expression`, `context`, `eye`, `smile`. Suggest the input describes observable cues.

Selection rules (in priority order):
1. If statement cues are present → use `statement_text` (matches on `Statement.text`). Statement cues take priority even when context cues are also present.
2. Else if context cues are present → use `tone_expression_context` (matches on `Context.value`).
3. Else → use `fallback_signal_pattern` as the primary.

**Trial order at query time** (`interpret.ts: interpretSituation`): the selected template runs first. If it returns no rows, the remaining non-fallback template is tried next. The `fallback_signal_pattern` always runs last. The first template to return rows wins; subsequent templates are skipped.

The `fallback_signal_pattern` template does no text matching — it returns all situations and their full signal/pattern chains, making it a broad catch-all when the input text does not overlap with anything stored in the graph.

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
