# Graph for interpreting social situations

This document describes a **simple example of a graph design** that
could help an autistic person interpret two situations where this person made a
mistake:

1.  Someone responds **with sarcasm**
2.  Someone responds **with genuine encouragement**

The goal is to illustrate how a **graph schema (structure)** and **graph
knowledge (weighted patterns)** can support reasoning from **observable
evidence** to **suggested interpretations**, optionally with an explicit
**probability** on each suggested interpretation when a situation matches a predefined pattern.

------------------------------------------------------------------------

# 1. Graph Schema (Structure)

The schema defines **what types of nodes exist and how they can
connect**.

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

<!--
  Note: Some node types above (Person, Statement, Tone, Expression, Context, Situation, and Signal)
  represent things we can directly observe in a situation.
  Others (Literal_Meaning, Intended_Meaning, Pattern) represent concepts that are inferred or abstract,
  such as how words are usually interpreted, what someone probably meant, or sets of signals to match.
-->

## Node Value Domains (allowed values for this simple example)
This schema provides a simple example. For concepts that could have many possible values, like person names or statements, the example uses a small, fixed set of allowed values. Each of these values is mapped to one of the main semantic node types in the graph: `Person`, `Statement`, `Tone`, `Expression`, `Context`, `LiteralMeaning`, `IntendedMeaning`, `Situation`, `Signal`, or `Pattern`.

### Person
Allowed Person values:
- `Alice`
- `Henry`

### Statement
Allowed Statement values:
- `"Great job"`
- `"You did your best"`

The system maps statement text to a **`LiteralMeaning`** node via `HAS_LITERAL_MEANING` (see `Literal Meaning of Statements` below). This is the **surface** reading of the words, not the social **intended** meaning.

### Tone
Allowed Tone node values:
- `annoyed_tone`
- `warm_tone`

<!-- 
  In a future, more complete specification, tone could be any of:
    - `neutral_tone`
    - `warm_tone`
    - `annoyed_tone`
    - `sarcastic_tone`
    - `enthusiastic_tone`
    - `sad_tone`
    - `hesitant_tone`
    - `angry_tone`
    - `reassuring_tone`
    - `dismissive_tone`
-->

### Expression
Allowed Expression node values:
- `eye_roll`
- `smile`
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
- `mistake_happened`

### LiteralMeaning
What the utterance **literally** communicates in this toy vocabulary (surface semantics).

Allowed LiteralMeaning values:
- `praise`
- `encouragement`

### IntendedMeaning
What the situation **plausibly communicates** given observable cues (social interpretation).

Allowed IntendedMeaning values in this toy example:
- `sarcasm`
- `criticism`
- `encouragement`

### Pattern

A **Pattern** is defined by a combination of specific `Signal` nodes.

A `Signal` node is a node that encodes the actual presence in a situation of a key feature (such as a particular tone, expression, context, or literal meaning), specifically for the purpose of pattern matching and interpretation. 

Unlike a base node (e.g., a `Tone` node with value `annoyed_tone`), which represents an abstract vocabulary value, a `Signal` node represents the *fact that this value is present in a specific situation* by linking the specific situation to the observed feature.

To clarify: a base node such as `Tone: annoyed_tone` is like a type or a class in programming; it is part of the general vocabulary available in the model, but does not refer to any particular situation or instance. In contrast, a `Signal` node with `kind: tone`, `valueId: annoyed_tone` specifically indicates that the "annoyed tone" is a feature observed in a particular situation, making it available for interpretation and pattern matching for that scenario.

It is important to distinguish between a **pattern** and a **scenario** (situation). A pattern is an abstract template that defines a particular combination of signal nodes—think of it as a specification of what cues, when present together, suggest a certain social interpretation. A scenario (also called a situation) is an actual, concrete instance: a real or hypothetical example where certain signals are present. The scenario may or may not match a defined pattern; if it does, the associated interpretation (IntendedMeaning) is inferred via the pattern. Patterns are generalizable rules, whereas scenarios are their specific, real-world instantiations.

Patterns identify which combination of these derived signals, when all present for a situation, provide evidence for a likely interpretation (IntendedMeaning).

When **all** required signals for a pattern are present for a given situation, the pattern may **`PREDICTS`→`IntendedMeaning`** with a numeric **`probability`**(see §2).

Patterns use:
- `patternId` (unique), e.g. `pattern_sarcasm_mistake_praise_annoyed`
- optional human-readable `description`

### Situation
Allowed Situation node values:
- `after_mistake_sarcasm` *(internal ID)* — **After Mistake: Sarcasm** (human-readable label)
- `after_mistake_encouragement` *(internal ID)* — **After Mistake: Encouragement** (human-readable label)

### Signal (derived)
`Signal` is a *derived* node used for pattern matching. In this toy spec,
exactly one `Signal` is produced for each required kind:
- tone signal: from `Situation -> HAS_TONE -> Tone`
- expression signal: from `Situation -> HAS_EXPRESSION -> Expression`
- context signal: from `Situation -> HAS_CONTEXT -> Context`
- literal meaning signal: from `Situation -> HAS_STATEMENT -> Statement -> HAS_LITERAL_MEANING -> LiteralMeaning`

Each `Signal` has:
- `kind` in `{tone, expression, context, literal_meaning}`
- `valueId` equal to the originating node's semantic value
  (e.g. `annoyed_tone`, `eye_roll`, `praise`)

## Relationship Types

*The following is a list of all the relationship types used in this graph schema:*

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
For this simple schema, assume the following constraints:

1. Type constraints (hard rule)
   Each relationship must connect the source/target node types exactly as
   named above.

2. Cardinality (per situation instance; toy defaults)
   - `Person → SAID → Statement`: a `Person` can SAID multiple statements; a
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

The graph stores social knowledge as **`Pattern`** nodes: each pattern lists the
**`Signal`** conjunction it needs (`REQUIRES`) and the **`IntendedMeaning`** it suggests
when that conjunction is present (`PREDICTS`), with an explicit **`probability`** on
`PREDICTS`.

**Semantics of `probability`.** In this toy graph, `probability` on `PREDICTS` is
**the pattern’s strength conditional on all of its `REQUIRES` signals being present**
(a designer-set value for teaching and prototyping, not an empirically calibrated
posterior unless you later fit it from data). Products may rename this to `confidence`
or normalize scores across competing fired patterns.

## Pattern Matching Semantics
This toy spec defines a simple, implementable matching procedure.

1. **Build a derived signal set** for a situation instance (same derived tokens as before):
   - `Situation -> HAS_TONE -> Tone` yields a `Signal { kind: tone, valueId: <toneValue> }`
   - `Situation -> HAS_EXPRESSION -> Expression` yields a `Signal { kind: expression, valueId: <expressionValue> }`
   - `Situation -> HAS_CONTEXT -> Context` yields a `Signal { kind: context, valueId: <contextValue> }`
   - `Situation -> HAS_STATEMENT -> Statement -> HAS_LITERAL_MEANING -> LiteralMeaning` yields a `Signal { kind: literal_meaning, valueId: <literalMeaningValue> }`

   Situation instances also link to the corresponding `Signal` vocabulary nodes via
   `Situation -> HAS_SIGNAL -> Signal` in the reference implementation.

2. A **`Pattern`** **fires** for that situation iff **every** `Signal` reached by
   `Pattern -> REQUIRES -> Signal` is contained in the situation’s derived / attached
   signal set (conjunctive match, same idea as before, but explicit in the graph).

3. When a pattern fires, read **`Pattern -> PREDICTS -> IntendedMeaning`** and report
   the **`probability`** property on `PREDICTS` as the suggested strength for that
   intended meaning (e.g. sarcasm with 0.8).

4. If **multiple patterns fire**, return **all** `(IntendedMeaning, probability)` pairs.
   If a **single** label is required, a simple policy is: choose the **`PREDICTS`**
   edge with the **highest** `probability`; if tied, return both.

## Pattern Token Legend (toy example)
The pattern names below are shorthand for required derived signal values:
- `praise_statement` means `literal_meaning = praise`
- `annoyance_expression` means `expression = eye_roll`
- `smile` means `expression = smile`
- `annoyed_tone` means `tone = annoyed_tone`
- `warm_tone` means `tone = warm_tone`
- `mistake_context` means `context = mistake_happened`

## Literal Meaning of Statements

"Great job" → literal meaning → praise\
"Nice work" → literal meaning → praise

In graph terms for this example:
- `"Great job"` `HAS_LITERAL_MEANING` → `LiteralMeaning { value: "praise" }`
- `"Nice work"` `HAS_LITERAL_MEANING` → `LiteralMeaning { value: "praise" }`

## Expressions

eye_roll → suggests → criticism\
smile → suggests → encouragement

In graph terms (toy usage):
- `eye_roll` is treated as evidence for `criticism`/`sarcasm` via the patterns below
- `smile` is treated as evidence for `encouragement` via the patterns below

## Tone

annoyed_tone → suggests → criticism\
warm_tone → suggests → encouragement

In graph terms:
- `annoyed_tone` is evidence for `sarcasm`
- `warm_tone` is evidence for `encouragement`

## Context

mistake_happened → increases probability → criticism\
mistake_happened → increases probability → encouragement

A mistake can lead to criticism **or** support depending on other
signals.

In this toy spec, `mistake_happened` is required context that disambiguates
between `sarcasm` and `encouragement` using the other signals in each
pattern.

------------------------------------------------------------------------

# 3. Pattern: Sarcasm

The graph stores a pattern describing sarcasm as a **conjunctive** match over signals,
with a numeric strength on the interpretation.

praise_statement\
+ annoyance_expression\
+ annoyed_tone\
+ mistake_context\
→ sarcasm **(0.8)**

Required derived signals for this toy pattern:
- `literal_meaning = praise`
- `expression = eye_roll`
- `tone = annoyed_tone`
- `context = mistake_happened`

In Neo4j terms: a `Pattern` node **`REQUIRES`** each corresponding `Signal` node, and
**`PREDICTS {probability: 0.8}`** the `IntendedMeaning` **`sarcasm`**.

This pattern means that when positive words appear together with
negative signals in a mistake context, sarcasm is **suggested** with strength **0.8**
(in this toy interpretation of `probability`).

------------------------------------------------------------------------

# 4. Pattern: Genuine Encouragement

Another pattern describes genuine support.

praise_statement\
+ smile\
+ warm_tone\
+ mistake_context\
→ encouragement **(0.85)**

Required derived signals for this toy pattern:
- `literal_meaning = praise`
- `expression = smile`
- `tone = warm_tone`
- `context = mistake_happened`

In Neo4j terms: **`PREDICTS {probability: 0.85}`** → `IntendedMeaning` **`encouragement`**.

This pattern indicates the compliment is **suggested** as supportive encouragement
with strength **0.85** in this toy example (slightly higher than the sarcasm pattern’s
0.8 only for illustration; real systems would calibrate both from data or expert priors).

------------------------------------------------------------------------

# 5. Situation A --- Sarcasm

The autistic person makes a mistake during a meeting.

A coworker says:

"Great job."

Observed signals:

-   Statement: "Great job"
-   Tone: annoyed
-   Expression: eye roll
-   Context: mistake happened

### Graph Representation
Nodes (ids) used in this example:
- `henry`: `Person { name: "Henry" }`
- `stmt_great_job`: `Statement { text: "Great job" }`
- `expr_eye_roll`: `Expression { value: "eye_roll" }`
- `tone_annoyed_tone`: `Tone { value: "annoyed_tone" }`
- `ctx_mistake_happened`: `Context { value: "mistake_happened" }`
- `literal_meaning_praise`: `LiteralMeaning { value: "praise" }` *(shared singleton)*

Edges (explicit instance):
- `henry` → `SAID` → `stmt_great_job`
- `henry` → `HAS_EXPRESSION` → `expr_eye_roll`
- `stmt_great_job` → `HAS_LITERAL_MEANING` → `literal_meaning_praise`
- `stmt_great_job` → `HAS_TONE` → `tone_annoyed_tone`
- `situation_a` → `HAS_SPEAKER` → `henry`
- `situation_a` → `HAS_STATEMENT` → `stmt_great_job`
- `situation_a` → `HAS_TONE` → `tone_annoyed_tone`
- `situation_a` → `HAS_EXPRESSION` → `expr_eye_roll`
- `situation_a` → `HAS_CONTEXT` → `ctx_mistake_happened`

Derived signals for pattern matching (Signal nodes):
- `Signal { kind: literal_meaning, valueId: praise }`
- `Signal { kind: expression, valueId: eye_roll }`
- `Signal { kind: tone, valueId: annoyed_tone }`
- `Signal { kind: context, valueId: mistake_happened }`

### Graph Reasoning

praise\
+ annoyed_tone\
+ eye_roll\
+ mistake_context\
→ sarcasm **(0.8)** when the conjunctive `Pattern` fires

### Interpretation

Although the words are positive, the tone and eye roll combined with the
mistake context suggest sarcasm or criticism.

------------------------------------------------------------------------

# 6. Situation B --- Genuine Encouragement

The autistic person again makes a mistake.

Another coworker says:

"Great job, you'll get it next time."

Observed signals:

-   Statement: "Great job"
-   Tone: warm
-   Expression: smile
-   Context: mistake happened

### Graph Representation
Nodes (ids) used in this example:
- `alice`: `Person { name: "Alice" }`
- `stmt_great_job_2`: `Statement { text: "Great job" }`
- `expr_smile`: `Expression { value: "smile" }`
- `tone_warm_tone`: `Tone { value: "warm_tone" }`
- `ctx_mistake_happened_2`: `Context { value: "mistake_happened" }`
- `literal_meaning_praise`: `LiteralMeaning { value: "praise" }` *(same shared singleton as Situation A)*

Edges (explicit instance):
- `alice` → `SAID` → `stmt_great_job_2`
- `alice` → `HAS_EXPRESSION` → `expr_smile`
- `stmt_great_job_2` → `HAS_LITERAL_MEANING` → `literal_meaning_praise`
- `stmt_great_job_2` → `HAS_TONE` → `tone_warm_tone`
- `situation_b` → `HAS_SPEAKER` → `alice`
- `situation_b` → `HAS_STATEMENT` → `stmt_great_job_2`
- `situation_b` → `HAS_TONE` → `tone_warm_tone`
- `situation_b` → `HAS_EXPRESSION` → `expr_smile`
- `situation_b` → `HAS_CONTEXT` → `ctx_mistake_happened_2`

Derived signals for pattern matching (Signal nodes):
- `Signal { kind: literal_meaning, valueId: praise }`
- `Signal { kind: expression, valueId: smile }`
- `Signal { kind: tone, valueId: warm_tone }`
- `Signal { kind: context, valueId: mistake_happened }`

### Graph Reasoning

praise\
+ smile\
+ warm_tone\
+ mistake_context\
→ encouragement **(0.85)** when the conjunctive `Pattern` fires

### Interpretation

The statement appears to be genuine encouragement. The warm tone and
smile suggest support rather than criticism.

------------------------------------------------------------------------

# 7. Key Insight

Both situations include the **same words**:

"Great job"

But the meaning changes depending on the **combination of signals**:

  Signal       Sarcasm Case   Encouragement Case
  ------------ -------------- --------------------
  Tone         annoyed        warm
  Expression   eye roll       smile
  Context      mistake        mistake

The graph enables reasoning based on **conjunctive signal patterns** with explicit
**probabilities on suggested intended meanings**, not just the literal meaning of words.

**Literal** interpretation (`LiteralMeaning`) is separated from **intended** social
meaning (`IntendedMeaning`).

------------------------------------------------------------------------

# 8. Purpose of This Graph

This simple graph demonstrates how a system could:

1.  Receive a description of a situation (observable evidence and, where needed, literal meaning of words)
2.  Extract **signals** from the situation
3.  Match those signals against stored **`Pattern`** combinations (`REQUIRES`)
4.  Read **`PREDICTS`** edges to obtain suggested **`IntendedMeaning`** values with an associated **`probability`**
