# Graph for interpreting social situations

This document shows a simple graph design for interpreting two social situations about feedback on a painting:

1.  Someone is speaking **with sarcasm**
2.  Someone is genuinely **complimenting and praising**

The goal is to show how a **graph schema** and **weighted patterns** can map observable cues to social interpretations, with an optional **probability** for each interpretation.

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
        <td style="padding: 6px;">This painting is unique and worthy of praise</td>
        <td style="padding: 6px;">Sarcastic criticism (implies the painting is not good)</td>
      </tr>
      <tr style="white-space: normal !important; overflow-wrap: anywhere; word-break: break-word; overflow: visible; text-overflow: clip;">
        <td style="padding: 6px;">Henry</td>
        <td style="padding: 6px;">They are looking at my painting</td>
        <td style="padding: 6px;">"It's great, it's very original"</td>
        <td style="padding: 6px;">enthusiastic_tone</td>
        <td style="padding: 6px;">awe</td>
        <td style="padding: 6px;">This painting is unique and worthy of praise</td>
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
-   Literal_Meaning
-   Intended_Meaning
-   Situation
-   Signal
-   Pattern

## Node Value Domains (allowed values for this simple example)
This is a small toy schema. Concepts that could have many values (like names or statements) are restricted here to a short allowed list. Each value maps to one of these node types: `Person`, `Statement`, `Tone`, `Expression`, `Context`, `LiteralMeaning`, `IntendedMeaning`, `Situation`, `Signal`, or `Pattern`.

### Common Optional Node Properties
In addition to type-specific fields, nodes may include these optional properties:
- `name`: short human-readable label
- `description`: longer natural-language explanation

These properties improve readability for people but do not change matching logic.

### Person
Allowed Person values:
- `Alice`
- `Henry`

### Statement
Allowed Statement values:
- `"It's great, it's very original"`
- `"Congratulations, it's definitely original"`

The system maps statement text to a **`LiteralMeaning`** node through `HAS_LITERAL_MEANING` (see `Literal Meaning of Statements` below). This is the surface meaning of the words, not the social intended meaning.

### Tone
Allowed Tone node values:
- `enthusiastic_tone`
- `dry_tone`

<!-- 
  In a future, more complete specification, tone could be any of:
    - `neutral_tone`
    - `enthusiastic_tone`
    - `dry_tone`
    - `sarcastic_tone`
    - `sad_tone`
    - `hesitant_tone`
    - `angry_tone`
    - `reassuring_tone`
    - `dismissive_tone`
    - `bored_tone`
-->

### Expression
Allowed Expression node values:
- `eye_roll`
- `awe`
<!-- 
  In a future, more complete specification, this list could include a wider set of facial expressions, such as:
    - `neutral`
    - `smirk`
    - `scowl`
    - `eye_roll`
    - `raised_eyebrows`
    - `grimace`
    - `pursed_lips`
    - `wide_eyes`
-->

### Context
Allowed Context node values:
- `They are looking at my painting`

### LiteralMeaning
What the utterance literally means in this toy vocabulary.

Allowed LiteralMeaning values:
- `praise`

### IntendedMeaning
What the situation plausibly means socially, given observable cues.

Allowed IntendedMeaning values in this toy example:
- `sarcasm`
- `indifference`
- `compliment`
- `praise`

### Pattern

A **Pattern** is a combination of specific `Signal` nodes.

A `Signal` node records that a key feature is present in a specific situation (such as tone, expression, context, or literal meaning). It is used for pattern matching.

Unlike a base node (for example, `Tone: dry_tone`), which is just a vocabulary value, a `Signal` node captures that the value is present in one specific situation.

In other words, `Tone: dry_tone` is general vocabulary. A `Signal` with `kind: tone` and `valueId: dry_tone` says that dry tone was observed in one concrete situation.

It is important to distinguish **pattern** vs **situation**. A pattern is a reusable rule (a cue combination). A situation is one concrete instance. A situation may or may not match a pattern; if it matches, the pattern suggests an `IntendedMeaning`.

Patterns define which signal combinations count as evidence for an `IntendedMeaning`.

When **all** required signals are present for a situation, the pattern can **`PREDICTS`→`IntendedMeaning`** with a numeric **`probability`** (see section 2).

Patterns use:
- A pattern should include a human-readable `description` of the cue combination it represents (for example, "Praise is given with an eye roll after a painting is shown")

### Situation
Allowed Situation node values:
- `painting_feedback_awe`
- `painting_feedback_eye_roll`

### Signal (derived)
`Signal` is a derived node used for pattern matching. In this toy spec, exactly one `Signal` is produced for each required kind:
- tone signal: from `Situation -> HAS_TONE -> Tone`
- expression signal: from `Situation -> HAS_EXPRESSION -> Expression`
- context signal: from `Situation -> HAS_CONTEXT -> Context`
- literal meaning signal: from `Situation -> HAS_STATEMENT -> Statement -> HAS_LITERAL_MEANING -> LiteralMeaning`

Each `Signal` has:
- `kind` in `{tone, expression, context, literal_meaning}`
- `valueId` equal to the originating node's semantic value
  (e.g. `dry_tone`, `eye_roll`, `praise`)

## Relationship Types

*The following relationship types are used in this schema:*

-   Person → SAID → Statement
-   Statement → HAS_LITERAL_MEANING → LiteralMeaning
-   Statement → HAS_TONE → Tone
-   Person → HAS_EXPRESSION → Expression
-   Situation → HAS_SPEAKER → Person
-   Situation → HAS_STATEMENT → Statement
-   Situation → HAS_TONE → Tone
-   Situation → HAS_EXPRESSION → Expression
-   Situation → HAS_CONTEXT → Context
-   Situation → HAS_SIGNAL → Signal
-   Pattern → REQUIRES → Signal
-   Pattern → PREDICTS → IntendedMeaning
-   Context → GENERATES_SIGNAL → Signal *(optional bridge: context observation to its signal token; same as in the reference Neo4j load)*


## Relationship Constraints (minimal validity rules)
Use the following minimal constraints:

1. Type constraints (hard rule)
   Each relationship must connect the source/target node types exactly as
   named above.

2. Cardinality (per situation instance; toy defaults)
   - `Person → SAID → Statement`: a `Person` can say multiple statements; a
     `Statement` is SAID by exactly one `Person`.
   - `Situation → HAS_SPEAKER → Person`: exactly one speaker in this toy schema.
   - `Situation → HAS_STATEMENT → Statement`: exactly one statement in this toy schema.
   - `Situation → HAS_TONE → Tone`: exactly one tone in this toy schema.
   - `Situation → HAS_EXPRESSION → Expression`: exactly one expression in this toy schema.
   - `Statement → HAS_LITERAL_MEANING → LiteralMeaning`: exactly one literal meaning
     in this toy schema.
   - `Statement → HAS_TONE → Tone`: exactly one tone in this toy schema.
   - `Person → HAS_EXPRESSION → Expression`: exactly one expression in this
     toy schema.
   - `Situation → HAS_CONTEXT → Context`: exactly one context in this toy schema.
   - `Situation → HAS_SIGNAL → Signal`: attaches the situation’s derived signal set for matching.
   - `Pattern → REQUIRES → Signal`: defines which signals must all be present for the pattern to apply.
   - `Pattern → PREDICTS → IntendedMeaning`: carries optional relationship property **`probability`**
     (see section 2). In Neo4j this is stored on the `PREDICTS` relationship (e.g. `probability: 0.8`).

------------------------------------------------------------------------

# 2. Graph Knowledge (Patterns)

The graph stores social knowledge as **`Pattern`** nodes. Each pattern lists the required **`Signal`** conjunction (`REQUIRES`) and the suggested **`IntendedMeaning`** (`PREDICTS`), with an explicit **`probability`** on `PREDICTS`.

**Semantics of `probability`.** In this toy graph, `probability` on `PREDICTS` is the pattern strength **assuming all required signals are present**. It is a designer-set value for teaching/prototyping, not a calibrated posterior unless later fit from data. Products may call this `confidence` or normalize scores across competing fired patterns.

## Pattern Matching Semantics
This toy spec uses a simple matching procedure.

1. **Build a derived signal set** for a situation:
   - `Situation -> HAS_TONE -> Tone` yields a `Signal { kind: tone, valueId: <toneValue> }`
   - `Situation -> HAS_EXPRESSION -> Expression` yields a `Signal { kind: expression, valueId: <expressionValue> }`
   - `Situation -> HAS_CONTEXT -> Context` yields a `Signal { kind: context, valueId: <contextValue> }`
   - `Situation -> HAS_STATEMENT -> Statement -> HAS_LITERAL_MEANING -> LiteralMeaning` yields a `Signal { kind: literal_meaning, valueId: <literalMeaningValue> }`

   Situation instances also link to the corresponding `Signal` vocabulary nodes via
   `Situation -> HAS_SIGNAL -> Signal` in the reference implementation.

2. A **`Pattern`** **fires** iff **every** `Signal` reached by `Pattern -> REQUIRES -> Signal` is in the situation’s derived/attached signal set (conjunctive match).

3. When a pattern fires, read **`Pattern -> PREDICTS -> IntendedMeaning`** and report the `probability` on `PREDICTS` as the strength for that interpretation (for example, sarcasm with 0.8).

4. If **multiple patterns fire**, return **all** `(IntendedMeaning, probability)` pairs. If one label is required, choose the `PREDICTS` edge with the highest `probability`; if tied, return both.

## Partial Matching for Incomplete Signals
This extension allows matching when not all required signals are present.
The default behavior remains strict conjunctive matching.

### Goal
- Keep current strict logic as default.
- Add an optional partial mode for incomplete evidence.
- Reuse the existing `PREDICTS.probability` value.

### Additional Properties
- On `Pattern`:
  - `match_mode` in `{all_required, partial}` (default: `all_required`)
  - `min_coverage` in `[0,1]` (used only when `match_mode = partial`; example: `0.6`)
- On `Pattern -> REQUIRES -> Signal`:
  - `weight` (optional float, default: `1.0`)

### Semantics
Given a pattern `P` with required signals `R`:
- Let `O ⊆ R` be the required signals observed in the situation.
- Let each required signal have weight `w_i` (default `1.0`).
- Compute:
  - `coverage = sum(w_i for i in O) / sum(w_i for i in R)`
- Firing rules:
  - If `match_mode = all_required`: existing rule applies (all required signals must be present).
  - If `match_mode = partial`: pattern is eligible only if `coverage >= min_coverage`.
- Probability in partial mode:
  - `adjusted_probability = base_probability * coverage`
  - where `base_probability` is `PREDICTS.probability`.

### Output Policy
- In strict mode, return the original `probability`.
- In partial mode, return `adjusted_probability`.
- If multiple patterns fire, rank by returned probability (original or adjusted).

### Notes
- Missing required signals do not auto-fail in partial mode.
- Missing high-weight signals reduce coverage more.
- No new node types are required for this extension.

## Pattern Token Legend (toy example)
The pattern names below are shorthand for required derived signal values:
- `praise_statement` means `literal_meaning = praise`
- `awe_expression` means `expression = awe`
- `eye_roll_expression` means `expression = eye_roll`
- `enthusiastic_tone` means `tone = enthusiastic_tone`
- `dry_tone` means `tone = dry_tone`
- `painting_context` means `context = They are looking at my painting`

## Literal Meaning of Statements

"It's great, it's very original" → literal meaning → praise\
"Congratulations, it's definitely original" → literal meaning → praise

In graph terms for this example:
- `"It's great, it's very original"` `HAS_LITERAL_MEANING` → `LiteralMeaning { value: "praise" }`
- `"Congratulations, it's definitely original"` `HAS_LITERAL_MEANING` → `LiteralMeaning { value: "praise" }`

## Expressions

awe → suggests → genuine praise\
eye_roll → suggests → sarcasm or contempt

In graph terms (toy usage):
- `awe` is treated as evidence for `compliment`/`praise` via the patterns below
- `eye_roll` is treated as evidence for `sarcasm`/`indifference` via the patterns below

## Tone

enthusiastic_tone → suggests → genuine praise\
dry_tone → suggests → sarcasm or indifference

In graph terms:
- `enthusiastic_tone` is evidence for `compliment`/`praise`
- `dry_tone` is evidence for `sarcasm`/`indifference`

## Context

They are looking at my painting → anchors interpretation to feedback about the artwork

In this toy spec, `They are looking at my painting` is the required context in
both situations, and tone + expression perform the disambiguation between
genuine praise and sarcasm.

------------------------------------------------------------------------

# 3. Pattern: Sarcasm

This pattern describes sarcasm as a conjunctive match over signals, with a numeric strength.

praise_statement\
+ eye_roll_expression\
+ dry_tone\
+ painting_context\
→ sarcasm **(0.8)**

Required derived signals for this toy pattern:
- `literal_meaning = praise`
- `expression = eye_roll`
- `tone = dry_tone`
- `context = They are looking at my painting`

In Neo4j terms: a `Pattern` node **`REQUIRES`** each corresponding `Signal` node, and
**`PREDICTS {probability: 0.8}`** the `IntendedMeaning` **`sarcasm`**.

This means that positive words plus negative paralinguistic cues in the painting context suggest sarcasm with strength **0.8**.

------------------------------------------------------------------------

# 4. Pattern: Genuine Praise

This pattern describes genuine positive feedback.

praise_statement\
+ awe_expression\
+ enthusiastic_tone\
+ painting_context\
→ praise **(0.85)**

Required derived signals for this toy pattern:
- `literal_meaning = praise`
- `expression = awe`
- `tone = enthusiastic_tone`
- `context = They are looking at my painting`

In Neo4j terms: **`PREDICTS {probability: 0.85}`** → `IntendedMeaning` **`praise`**.

This pattern suggests genuine praise with strength **0.85** in this toy example. The higher value than sarcasm (0.8) is only illustrative; real systems would calibrate both from data or expert priors.

------------------------------------------------------------------------

# 5. Situation A --- Sarcasm

A person is looking at my painting.

They say:

"Congratulations, it's definitely original."

Observed signals:

-   Statement: "Congratulations, it's definitely original"
-   Tone: dry
-   Expression: eye roll
-   Context: They are looking at my painting

### Graph Representation
Nodes (ids) used in this example:
- `situation_a`: `Situation { name: "Dry congratulations with eye roll", description: "A person is looking at my painting and says 'Congratulations, it's definitely original' in a dry tone with an eye-roll expression." }`
- `henry`: `Person { name: "Henry" }`
- `stmt_congrats_original`: `Statement { text: "Congratulations, it's definitely original" }`
- `expr_eye_roll`: `Expression { value: "eye_roll" }`
- `tone_dry_tone`: `Tone { value: "dry_tone" }`
- `ctx_painting`: `Context { value: "They are looking at my painting" }`
- `literal_meaning_praise`: `LiteralMeaning { value: "praise" }` *(shared singleton)*

Edges (explicit instance):
- `henry` → `SAID` → `stmt_congrats_original`
- `henry` → `HAS_EXPRESSION` → `expr_eye_roll`
- `stmt_congrats_original` → `HAS_LITERAL_MEANING` → `literal_meaning_praise`
- `stmt_congrats_original` → `HAS_TONE` → `tone_dry_tone`
- `situation_a` → `HAS_SPEAKER` → `henry`
- `situation_a` → `HAS_STATEMENT` → `stmt_congrats_original`
- `situation_a` → `HAS_TONE` → `tone_dry_tone`
- `situation_a` → `HAS_EXPRESSION` → `expr_eye_roll`
- `situation_a` → `HAS_CONTEXT` → `ctx_painting`

Derived signals for pattern matching (Signal nodes):
- `Signal { kind: literal_meaning, valueId: praise }`
- `Signal { kind: expression, valueId: eye_roll }`
- `Signal { kind: tone, valueId: dry_tone }`
- `Signal { kind: context, valueId: They are looking at my painting }`

### Graph Reasoning

praise\
+ dry_tone\
+ eye_roll\
+ painting_context\
→ sarcasm **(0.8)** when the conjunctive `Pattern` fires

### Interpretation

Although the words are positive, the dry tone and eye roll in this painting context suggest sarcasm or dismissiveness.

------------------------------------------------------------------------

# 6. Situation B --- Genuine Praise

A person is looking at my painting.

They say:

"It's great, it's very original."

Observed signals:

-   Statement: "It's great, it's very original"
-   Tone: enthusiastic
-   Expression: awe
-   Context: They are looking at my painting

### Graph Representation
Nodes (ids) used in this example:
- `situation_b`: `Situation { name: "Enthusiastic praise with awe", description: "A person is looking at my painting and says 'It's great, it's very original' in an enthusiastic tone with an expression of awe." }`
- `alice`: `Person { name: "Alice" }`
- `stmt_great_original`: `Statement { text: "It's great, it's very original" }`
- `expr_awe`: `Expression { value: "awe" }`
- `tone_enthusiastic_tone`: `Tone { value: "enthusiastic_tone" }`
- `ctx_painting_2`: `Context { value: "They are looking at my painting" }`
- `literal_meaning_praise`: `LiteralMeaning { value: "praise" }` *(same shared singleton as Situation A)*

Edges (explicit instance):
- `alice` → `SAID` → `stmt_great_original`
- `alice` → `HAS_EXPRESSION` → `expr_awe`
- `stmt_great_original` → `HAS_LITERAL_MEANING` → `literal_meaning_praise`
- `stmt_great_original` → `HAS_TONE` → `tone_enthusiastic_tone`
- `situation_b` → `HAS_SPEAKER` → `alice`
- `situation_b` → `HAS_STATEMENT` → `stmt_great_original`
- `situation_b` → `HAS_TONE` → `tone_enthusiastic_tone`
- `situation_b` → `HAS_EXPRESSION` → `expr_awe`
- `situation_b` → `HAS_CONTEXT` → `ctx_painting_2`

Derived signals for pattern matching (Signal nodes):
- `Signal { kind: literal_meaning, valueId: praise }`
- `Signal { kind: expression, valueId: awe }`
- `Signal { kind: tone, valueId: enthusiastic_tone }`
- `Signal { kind: context, valueId: They are looking at my painting }`

### Graph Reasoning

praise\
+ awe\
+ enthusiastic_tone\
+ painting_context\
→ praise **(0.85)** when the conjunctive `Pattern` fires

### Interpretation

The statement appears to be genuine praise. The enthusiastic tone and awe expression suggest admiration rather than sarcasm.

------------------------------------------------------------------------

------------------------------------------------------------------------

# 7. Purpose of This Graph

This simple graph shows how a system can:

1.  Receive a description of a situation (observable evidence and, when needed, literal meaning)
2.  Extract derived **signals** for that situation
3.  Match those signals against stored **`Pattern`** conjunctions (`REQUIRES`)
4.  Read **`PREDICTS`** edges to get suggested **`IntendedMeaning`** values with associated **`probability`**
