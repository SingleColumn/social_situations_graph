# Graph for interpreting social situations

This document shows a simple graph design for interpreting two social situations about feedback on a painting:

1.  Someone is speaking **with sarcasm**
2.  Someone is genuinely **complimenting and praising**

The goal is to show how a **graph schema** and **weighted patterns** can map observable cues to social interpretations, with an optional **probability** for each interpretation.

------------------------------------------------------------------------

# Design Principles

The following principles guided every structural decision in this graph. They are stated here so that future extensions remain consistent with the original intent.

## 1. Separate vocabulary from evidence

Nodes that represent general concepts — `Tone`, `Expression`, `LiteralMeaning`, `SignalType` — are shared across all situations. They are defined once and reused. Nodes that represent what was observed in a specific situation — `SituationSignal`, `Statement` instances — are created per situation and never shared.

This separation prevents one situation's data from contaminating another's subgraph, and keeps the schema clean: vocabulary grows slowly, evidence grows as new situations are added.

## 2. Patterns are reusable rules, not situation-specific wiring

A `Pattern` defines a conjunction of `SignalType` nodes (shared vocabulary). It is written once and fires for any situation whose evidence covers the required signal types. Patterns are never modified when new situations are added.

This is enforced by having `Pattern → REQUIRES → SignalType` (not `SituationSignal`). The instance-level bridge `SituationSignal → INSTANCE_OF → SignalType` is what connects a concrete situation to the reusable pattern vocabulary at query time.

## 3. Situations are self-contained subgraphs

All nodes that belong to a situation are reachable from its `Situation` node by following outgoing edges only. The only exceptions are shared vocabulary nodes (`SignalType`, `LiteralMeaning`, `Context`), which are reached via `INSTANCE_OF` or direct `HAS_*` edges and are intentionally shared.

This makes it possible to extract a clean subgraph for any single situation without traversal leaking into other situations.

## 4. Two channels: observation and inference

Edges are divided into two semantic channels:

- **Literal channel** — records what was directly observed: who said what, with what tone and expression, in what context. Edges: `SAID`, `HAS_STATEMENT`, `HAS_TONE`, `HAS_EXPRESSION`, `HAS_CONTEXT`, `HAS_SPEAKER`, `HAS_LITERAL_MEANING`.
- **Inference channel** — records the reasoning from evidence to interpretation: which signals were derived, which patterns apply, what meanings are predicted. Edges: `HAS_SIGNAL`, `INSTANCE_OF`, `REQUIRES`, `PREDICTS`.

Keeping the channels distinct makes it possible to query or visualise either the factual record or the reasoning chain independently.

## 5. Probability lives on the prediction edge, not the pattern node

The `probability` property is placed on the `PREDICTS` edge, not on the `Pattern` node. This allows a single pattern to predict multiple intended meanings with different strengths, and makes it straightforward to compare competing predictions from different patterns for the same situation.

## 6. Uniqueness is explicit, not implicit

Every node type that could be accidentally duplicated has an explicit uniqueness rule:
- `SignalType`: unique on `(kind, valueId)` — one node per cue type in the entire graph.
- `SituationSignal`: unique on `(situationId, kind, valueId)` — one evidence node per cue per situation.

Without these rules, implementors can inadvertently share nodes that should be isolated (causing cross-situation contamination) or duplicate nodes that should be shared (causing missed pattern matches).

------------------------------------------------------------------------

## Example Scenarios Table (HTML)

<div style="width: 100%; overflow-x: auto;">
  <table style="width: 100%; table-layout: fixed; border-collapse: collapse; font-size: 11px; line-height: 1.25;">
    <thead>
      <tr style="white-space: normal !important; overflow-wrap: anywhere; word-break: break-word; overflow: visible; text-overflow: clip;">
        <th style="padding: 6px;">Person</th>
        <th style="padding: 6px;">Context</th>
        <th style="padding: 6px;">Statement</th>
        <th style="padding: 6px;">Tone</th>
        <th style="padding: 6px;">Expression</th>
        <th style="padding: 6px;">Literal_Meaning</th>
        <th style="padding: 6px;">Intended_Meaning</th>
      </tr>
    </thead>
    <tbody>
      <tr style="white-space: normal !important; overflow-wrap: anywhere; word-break: break-word; overflow: visible; text-overflow: clip;">
        <td style="padding: 6px;">Alice</td>
        <td style="padding: 6px;">They are looking at my painting</td>
        <td style="padding: 6px;">"Congratulations, it's definitely original"</td>
        <td style="padding: 6px;">dry_tone</td>
        <td style="padding: 6px;">eye_roll</td>
        <td style="padding: 6px;">praise</td>
        <td style="padding: 6px;">Sarcastic criticism (implies the painting is not good)</td>
      </tr>
      <tr style="white-space: normal !important; overflow-wrap: anywhere; word-break: break-word; overflow: visible; text-overflow: clip;">
        <td style="padding: 6px;">Henry</td>
        <td style="padding: 6px;">They are looking at my painting</td>
        <td style="padding: 6px;">"It's great, it's very original"</td>
        <td style="padding: 6px;">enthusiastic_tone</td>
        <td style="padding: 6px;">awe</td>
        <td style="padding: 6px;">praise</td>
        <td style="padding: 6px;">Genuine compliment and praise</td>
      </tr>
    </tbody>
  </table>
</div>

------------------------------------------------------------------------

# 1. Graph Schema (Structure)

The schema defines which node types exist and how they connect.

## Node Types

-   Person
-   Statement
-   Tone
-   Expression
-   Context
-   LiteralMeaning
-   IntendedMeaning
-   Situation
-   SignalType
-   SituationSignal
-   Pattern

## Node Value Domains (allowed values for this simple example)

This is a small toy schema. Concepts that could have many values (like names or statements) are restricted here to a short allowed list.

### Common Optional Node Properties
In addition to type-specific fields, nodes may include these optional properties:
- `name`: short human-readable label
- `description`: longer natural-language explanation

These properties improve readability for people but do not change matching logic.

### Person
Allowed values:
- `Alice`
- `Henry`

### Statement
Allowed values:
- `"It's great, it's very original"`
- `"Congratulations, it's definitely original"`

The system maps statement text to a **`LiteralMeaning`** node through `HAS_LITERAL_MEANING`. This is the surface meaning of the words, not the social intended meaning.

### Tone
Allowed values:
- `enthusiastic_tone`
- `dry_tone`

### Expression
Allowed values:
- `eye_roll`
- `awe`

### Context
Allowed values:
- `They are looking at my painting`

### LiteralMeaning
What the utterance literally means in this toy vocabulary.

Allowed values:
- `praise`

Note: `LiteralMeaning` nodes are **shared singletons** — both situations that map to the same literal meaning point to the same node. This is intentional: literal meaning is a vocabulary concept, not a per-situation instance.

### IntendedMeaning
What the situation plausibly means socially, given observable cues.

Allowed values:
- `sarcasm`
- `indifference`
- `compliment`
- `praise`

### SignalType
A **SignalType** is a reusable vocabulary node representing a class of observable cue. It is not tied to any situation. Patterns reference SignalType nodes so that a single pattern definition can fire across any situation that produces matching evidence.

Each SignalType has:
- `kind` in `{tone, expression, context, literal_meaning}`
- `valueId`: the semantic value (e.g. `dry_tone`, `eye_roll`, `praise`)

**Uniqueness rule:** `(kind, valueId)` must be unique across all SignalType nodes. There is exactly one SignalType node per `(kind, valueId)` pair in the entire graph.

Allowed SignalType nodes for this toy schema:
- `{ kind: tone,           valueId: dry_tone }`
- `{ kind: tone,           valueId: enthusiastic_tone }`
- `{ kind: expression,     valueId: eye_roll }`
- `{ kind: expression,     valueId: awe }`
- `{ kind: context,        valueId: They are looking at my painting }`
- `{ kind: literal_meaning, valueId: praise }`

### SituationSignal
A **SituationSignal** is an instance node that records that a specific SignalType was observed in one specific situation. It is the bridge between a concrete situation and the reusable SignalType vocabulary.

Each SituationSignal has:
- `situationSignalId`: unique identifier (e.g. `sig_a_tone`)
- `situationId`: the situation it belongs to

**Uniqueness rule:** `(situationId, kind, valueId)` must be unique. Each situation produces at most one SituationSignal per SignalType. Because SituationSignal is scoped to a situation, two situations with the same tone each get their own SituationSignal node pointing to the shared SignalType.

Relationships:
- `Situation → HAS_SIGNAL → SituationSignal` (scopes the signal instance to the situation)
- `SituationSignal → INSTANCE_OF → SignalType` (links the instance to its vocabulary type)

### Pattern
A **Pattern** is a reusable rule defined as a required conjunction of **SignalType** nodes. Because patterns reference SignalTypes (not SituationSignals), a pattern is defined once and can fire for any situation — present, past, or future — whose SituationSignals cover all required SignalTypes.

Pattern properties:
- `patternId`: unique identifier
- `description`: human-readable explanation of the cue combination (e.g. "Praise given with an eye roll in a painting context suggests sarcasm")
- `match_mode` in `{all_required, partial}` (default: `all_required`)
- `min_coverage` in `[0,1]`: minimum coverage ratio required when `match_mode = partial` (e.g. `0.6`)

### Situation
Allowed values:
- `painting_feedback_sarcasm` (Alice, dry congratulations with eye roll)
- `painting_feedback_genuine_praise` (Henry, enthusiastic praise with awe)

------------------------------------------------------------------------

## Relationship Types

### Observational edges (literal channel)
These edges record what was said and how.

- `Person → SAID → Statement`
- `Statement → HAS_LITERAL_MEANING → LiteralMeaning`
- `Statement → HAS_TONE → Tone`
- `Person → HAS_EXPRESSION → Expression`
- `Situation → HAS_SPEAKER → Person`
- `Situation → HAS_STATEMENT → Statement`
- `Situation → HAS_TONE → Tone`
- `Situation → HAS_EXPRESSION → Expression`
- `Situation → HAS_CONTEXT → Context`

**Note on redundancy:** `Situation → HAS_TONE → Tone` and `Situation → HAS_EXPRESSION → Expression` are the **authoritative edges** used for signal derivation and pattern matching. `Statement → HAS_TONE → Tone` and `Person → HAS_EXPRESSION → Expression` are supplementary edges that enrich the graph for querying but are not part of the matching pipeline.

**Note on `HAS_SPEAKER`:** `Situation → HAS_SPEAKER → Person` is a direct convenience edge. It avoids traversing `Situation → HAS_STATEMENT → Statement ← SAID ← Person` to find the speaker. Both paths are valid; `HAS_SPEAKER` is preferred when the speaker is needed directly.

### Signal edges (inference channel)
These edges record derived evidence and pattern knowledge.

- `Situation → HAS_SIGNAL → SituationSignal`
- `SituationSignal → INSTANCE_OF → SignalType`
- `Pattern → REQUIRES → SignalType`
- `Pattern → PREDICTS → IntendedMeaning`

------------------------------------------------------------------------

## Relationship Properties

- `Pattern → REQUIRES → SignalType`: optional `weight` (float, default `1.0`). Used in partial matching to give more importance to certain signals.
- `Pattern → PREDICTS → IntendedMeaning`: required `probability` (float in `[0,1]`). The strength of this interpretation when the pattern fires.

------------------------------------------------------------------------

## Relationship Constraints (minimal validity rules)

1. **Type constraints (hard rule)**
   Each relationship must connect source and target node types exactly as listed above.

2. **Cardinality (per situation instance; toy defaults)**
   - `Situation → HAS_SPEAKER → Person`: exactly one speaker.
   - `Situation → HAS_STATEMENT → Statement`: exactly one statement.
   - `Situation → HAS_TONE → Tone`: exactly one tone.
   - `Situation → HAS_EXPRESSION → Expression`: exactly one expression.
   - `Situation → HAS_CONTEXT → Context`: exactly one context.
   - `Statement → HAS_LITERAL_MEANING → LiteralMeaning`: exactly one literal meaning.
   - `Statement → HAS_TONE → Tone`: exactly one tone (same value as `Situation → HAS_TONE`).
   - `Person → HAS_EXPRESSION → Expression`: exactly one expression (same value as `Situation → HAS_EXPRESSION`).
   - `Situation → HAS_SIGNAL → SituationSignal`: one SituationSignal per derived signal kind (tone, expression, context, literal_meaning), so exactly four in this toy schema.
   - `SituationSignal → INSTANCE_OF → SignalType`: exactly one per SituationSignal.
   - `Pattern → REQUIRES → SignalType`: one or more; defines the conjunction.
   - `Pattern → PREDICTS → IntendedMeaning`: one or more per pattern.

3. **Uniqueness constraints**
   - `SignalType`: unique on `(kind, valueId)`.
   - `SituationSignal`: unique on `(situationId, kind, valueId)` — enforced by the graph structure (one SituationSignal per situation per SignalType).

------------------------------------------------------------------------

# 2. Graph Knowledge (Patterns)

The graph stores social knowledge as **Pattern** nodes. Each pattern lists the required **SignalType** conjunction (`REQUIRES`) and the suggested **IntendedMeaning** (`PREDICTS`), with a `probability` on the `PREDICTS` edge.

**Semantics of `probability`:** In this toy graph, `probability` on `PREDICTS` is the pattern strength **assuming all required signals are present**. It is a designer-set value for teaching/prototyping, not a calibrated posterior.

## Pattern Matching Semantics

Given a situation, the matching procedure is:

1. **Build the situation's signal set** — collect all `SignalType` nodes reachable via:
   ```
   Situation → HAS_SIGNAL → SituationSignal → INSTANCE_OF → SignalType
   ```
   This yields a set of SignalType nodes (the observed evidence).

2. **Test each Pattern** — a Pattern **fires** if and only if every SignalType it `REQUIRES` is in the situation's signal set (conjunctive match).

3. **Read predictions** — when a pattern fires, follow `Pattern → PREDICTS → IntendedMeaning` and collect `(IntendedMeaning, probability)` pairs.

4. **Multiple firing patterns** — return all `(IntendedMeaning, probability)` pairs. If a single answer is required, choose the highest `probability`; if tied, return both.

**Why this works across situations:** Because `Pattern → REQUIRES → SignalType` references shared vocabulary nodes, the same pattern definition fires for any situation whose SituationSignals cover the required SignalTypes. Adding a new situation never requires modifying existing patterns.

## Partial Matching for Incomplete Signals

This extension allows matching when not all required signals are present.

### Additional Properties
These properties are defined on Pattern nodes and REQUIRES edges (see Relationship Properties above):
- On `Pattern`: `match_mode`, `min_coverage`
- On `Pattern → REQUIRES → SignalType`: `weight`

### Semantics
Given a pattern `P` with required SignalTypes `R`:
- Let `O ⊆ R` be the SignalTypes observed in the situation.
- Let each required SignalType have weight `w_i` (default `1.0`).
- Compute: `coverage = sum(w_i for i in O) / sum(w_i for i in R)`
- Firing rules:
  - If `match_mode = all_required`: all required SignalTypes must be present.
  - If `match_mode = partial`: pattern is eligible only if `coverage >= min_coverage`.
- In partial mode: `adjusted_probability = base_probability * coverage`

## Pattern Token Legend (toy example)
- `praise_statement` means `SignalType { kind: literal_meaning, valueId: praise }`
- `awe_expression` means `SignalType { kind: expression, valueId: awe }`
- `eye_roll_expression` means `SignalType { kind: expression, valueId: eye_roll }`
- `enthusiastic_tone` means `SignalType { kind: tone, valueId: enthusiastic_tone }`
- `dry_tone` means `SignalType { kind: tone, valueId: dry_tone }`
- `painting_context` means `SignalType { kind: context, valueId: They are looking at my painting }`

## Literal Meaning of Statements

Both statements map to the same literal meaning:
- `"Congratulations, it's definitely original"` → `HAS_LITERAL_MEANING` → `LiteralMeaning { value: praise }`
- `"It's great, it's very original"` → `HAS_LITERAL_MEANING` → `LiteralMeaning { value: praise }`

This is expected: both statements are surface-level compliments. The difference in intended meaning is carried by tone and expression, not by the words themselves.

## Expressions

- `awe` → evidence for genuine praise via patterns below
- `eye_roll` → evidence for sarcasm/contempt via patterns below

## Tone

- `enthusiastic_tone` → evidence for genuine praise
- `dry_tone` → evidence for sarcasm/indifference

## Context

`They are looking at my painting` anchors interpretation to feedback about the artwork. In this toy spec, context is shared by both situations; tone and expression perform the disambiguation.

------------------------------------------------------------------------

# 3. Pattern: Sarcasm

```
praise_statement
+ eye_roll_expression
+ dry_tone
+ painting_context
→ sarcasm (0.8)
```

Required SignalTypes:
- `SignalType { kind: literal_meaning, valueId: praise }`
- `SignalType { kind: expression,     valueId: eye_roll }`
- `SignalType { kind: tone,           valueId: dry_tone }`
- `SignalType { kind: context,        valueId: They are looking at my painting }`

In Neo4j terms: a `Pattern` node **`REQUIRES`** each of the four SignalType nodes above, and **`PREDICTS { probability: 0.8 }`** the `IntendedMeaning { value: sarcasm }`.

This pattern fires for any situation whose derived signal set contains all four SignalTypes. Adding a new situation with the same cues will fire this pattern without any changes to the pattern definition.

------------------------------------------------------------------------

# 4. Pattern: Genuine Praise

```
praise_statement
+ awe_expression
+ enthusiastic_tone
+ painting_context
→ praise (0.85)
```

Required SignalTypes:
- `SignalType { kind: literal_meaning, valueId: praise }`
- `SignalType { kind: expression,     valueId: awe }`
- `SignalType { kind: tone,           valueId: enthusiastic_tone }`
- `SignalType { kind: context,        valueId: They are looking at my painting }`

In Neo4j terms: **`PREDICTS { probability: 0.85 }`** → `IntendedMeaning { value: praise }`.

------------------------------------------------------------------------

# 5. Situation A — Sarcasm

A person is looking at my painting.

They say: *"Congratulations, it's definitely original."*

Observed cues:
- Statement: "Congratulations, it's definitely original"
- Tone: dry
- Expression: eye roll
- Context: They are looking at my painting

### Graph Representation

Nodes:
- `situation_a`: `Situation { situationId: "painting_feedback_sarcasm", description: "Alice looks at my painting and says 'Congratulations, it's definitely original' in a dry tone with an eye-roll expression." }`
- `alice`: `Person { name: "Alice" }`
- `stmt_congrats`: `Statement { text: "Congratulations, it's definitely original" }`
- `expr_eye_roll`: `Expression { value: "eye_roll" }`
- `tone_dry`: `Tone { value: "dry_tone" }`
- `ctx_painting`: `Context { value: "They are looking at my painting" }`
- `literal_meaning_praise`: `LiteralMeaning { value: "praise" }` *(shared singleton)*

Observational edges:
- `alice` → `SAID` → `stmt_congrats`
- `alice` → `HAS_EXPRESSION` → `expr_eye_roll`
- `stmt_congrats` → `HAS_LITERAL_MEANING` → `literal_meaning_praise`
- `stmt_congrats` → `HAS_TONE` → `tone_dry`
- `situation_a` → `HAS_SPEAKER` → `alice`
- `situation_a` → `HAS_STATEMENT` → `stmt_congrats`
- `situation_a` → `HAS_TONE` → `tone_dry`
- `situation_a` → `HAS_EXPRESSION` → `expr_eye_roll`
- `situation_a` → `HAS_CONTEXT` → `ctx_painting`

Derived signal edges:

| SituationSignal node | INSTANCE_OF SignalType |
|---|---|
| `sig_a_literal` | `{ kind: literal_meaning, valueId: praise }` |
| `sig_a_expression` | `{ kind: expression, valueId: eye_roll }` |
| `sig_a_tone` | `{ kind: tone, valueId: dry_tone }` |
| `sig_a_context` | `{ kind: context, valueId: They are looking at my painting }` |

All four SituationSignals point to the same four SignalTypes required by `pattern_sarcasm`. The pattern fires and **predicts sarcasm (0.8)**.

`pattern_genuine_praise` requires `{ kind: expression, valueId: awe }` and `{ kind: tone, valueId: enthusiastic_tone }`, neither of which is in Situation A's signal set. That pattern does **not** fire.

------------------------------------------------------------------------

# 6. Situation B — Genuine Praise

A person is looking at my painting.

They say: *"It's great, it's very original."*

Observed cues:
- Statement: "It's great, it's very original"
- Tone: enthusiastic
- Expression: awe
- Context: They are looking at my painting

### Graph Representation

Nodes:
- `situation_b`: `Situation { situationId: "painting_feedback_genuine_praise", description: "Henry looks at my painting and says 'It's great, it's very original' in an enthusiastic tone with an expression of awe." }`
- `henry`: `Person { name: "Henry" }`
- `stmt_great`: `Statement { text: "It's great, it's very original" }`
- `expr_awe`: `Expression { value: "awe" }`
- `tone_enthusiastic`: `Tone { value: "enthusiastic_tone" }`
- `ctx_painting`: `Context { value: "They are looking at my painting" }` *(same node as Situation A)*
- `literal_meaning_praise`: `LiteralMeaning { value: "praise" }` *(same shared singleton as Situation A)*

Observational edges:
- `henry` → `SAID` → `stmt_great`
- `henry` → `HAS_EXPRESSION` → `expr_awe`
- `stmt_great` → `HAS_LITERAL_MEANING` → `literal_meaning_praise`
- `stmt_great` → `HAS_TONE` → `tone_enthusiastic`
- `situation_b` → `HAS_SPEAKER` → `henry`
- `situation_b` → `HAS_STATEMENT` → `stmt_great`
- `situation_b` → `HAS_TONE` → `tone_enthusiastic`
- `situation_b` → `HAS_EXPRESSION` → `expr_awe`
- `situation_b` → `HAS_CONTEXT` → `ctx_painting`

Derived signal edges:

| SituationSignal node | INSTANCE_OF SignalType |
|---|---|
| `sig_b_literal` | `{ kind: literal_meaning, valueId: praise }` |
| `sig_b_expression` | `{ kind: expression, valueId: awe }` |
| `sig_b_tone` | `{ kind: tone, valueId: enthusiastic_tone }` |
| `sig_b_context` | `{ kind: context, valueId: They are looking at my painting }` |

All four SituationSignals point to the same four SignalTypes required by `pattern_genuine_praise`. The pattern fires and **predicts praise (0.85)**.

`pattern_sarcasm` requires `{ kind: expression, valueId: eye_roll }` and `{ kind: tone, valueId: dry_tone }`, neither of which is in Situation B's signal set. That pattern does **not** fire.

------------------------------------------------------------------------

# 7. Purpose of This Graph

This simple graph shows how a system can:

1.  Receive a description of a situation (observable evidence and, when needed, literal meaning)
2.  Extract derived **SituationSignal** instances for that situation
3.  Match those signals against stored **Pattern** conjunctions via shared **SignalType** vocabulary nodes
4.  Read **`PREDICTS`** edges to get suggested **IntendedMeaning** values with associated **probability**

The two-level signal design (SignalType + SituationSignal) ensures that:
- Patterns are defined once and remain valid for any future situation
- Each situation's evidence is fully isolated in its own SituationSignal nodes
- Shared vocabulary nodes (SignalType, LiteralMeaning, Context) do not cause cross-situation contamination in subgraph queries
