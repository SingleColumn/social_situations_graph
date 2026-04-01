---NEO4J_CYPHER---
// ============================================================
// CONSTRAINTS AND INDEXES
// ============================================================

// Person uniqueness
CREATE CONSTRAINT person_name_unique IF NOT EXISTS
FOR (p:Person) REQUIRE p.name IS UNIQUE;

// Tone uniqueness
CREATE CONSTRAINT tone_value_unique IF NOT EXISTS
FOR (t:Tone) REQUIRE t.value IS UNIQUE;

// Expression uniqueness
CREATE CONSTRAINT expression_value_unique IF NOT EXISTS
FOR (e:Expression) REQUIRE e.value IS UNIQUE;

// Context uniqueness
CREATE CONSTRAINT context_value_unique IF NOT EXISTS
FOR (c:Context) REQUIRE c.value IS UNIQUE;

// LiteralMeaning uniqueness
CREATE CONSTRAINT literal_meaning_value_unique IF NOT EXISTS
FOR (lm:LiteralMeaning) REQUIRE lm.value IS UNIQUE;

// IntendedMeaning uniqueness
CREATE CONSTRAINT intended_meaning_value_unique IF NOT EXISTS
FOR (im:IntendedMeaning) REQUIRE im.value IS UNIQUE;

// Situation uniqueness
CREATE CONSTRAINT situation_id_unique IF NOT EXISTS
FOR (s:Situation) REQUIRE s.situationId IS UNIQUE;

// Pattern uniqueness
CREATE CONSTRAINT pattern_id_unique IF NOT EXISTS
FOR (p:Pattern) REQUIRE p.patternId IS UNIQUE;

// Signal uniqueness by kind + valueId
CREATE CONSTRAINT signal_kind_value_unique IF NOT EXISTS
FOR (sig:Signal) REQUIRE (sig.kind, sig.valueId) IS NODE KEY;

// Statement uniqueness by statementId (never on text)
CREATE CONSTRAINT statement_id_unique IF NOT EXISTS
FOR (st:Statement) REQUIRE st.statementId IS UNIQUE;

// Indexes for common lookups
CREATE INDEX signal_kind_idx IF NOT EXISTS FOR (sig:Signal) ON (sig.kind);
CREATE INDEX signal_value_idx IF NOT EXISTS FOR (sig:Signal) ON (sig.valueId);
CREATE INDEX pattern_match_mode_idx IF NOT EXISTS FOR (p:Pattern) ON (p.match_mode);

// ============================================================
// SAMPLE DATA LOAD
// ============================================================

// ------------------------------------------------------------
// 1. Vocabulary nodes (shared singletons)
// ------------------------------------------------------------

// Persons
MERGE (alice:Person { name: "Alice" });
MERGE (henry:Person { name: "Henry" });

// Tones
MERGE (tone_dry:Tone { value: "dry_tone" })
  SET tone_dry.name = "Dry Tone",
      tone_dry.description = "A flat, unenthusiastic delivery that often signals sarcasm or indifference.";

MERGE (tone_enth:Tone { value: "enthusiastic_tone" })
  SET tone_enth.name = "Enthusiastic Tone",
      tone_enth.description = "An energetic, warm delivery that suggests genuine positive feeling.";

// Expressions
MERGE (expr_roll:Expression { value: "eye_roll" })
  SET expr_roll.name = "Eye Roll",
      expr_roll.description = "A facial gesture suggesting sarcasm, contempt, or dismissiveness.";

MERGE (expr_awe:Expression { value: "awe" })
  SET expr_awe.name = "Awe",
      expr_awe.description = "An expression of wonder or admiration suggesting genuine positive reaction.";

// Context
MERGE (ctx_painting:Context { value: "They are looking at my painting" })
  SET ctx_painting.name = "Painting Feedback Context",
      ctx_painting.description = "The observer is viewing the speaker's painting, anchoring interpretation to artwork feedback.";

// LiteralMeaning (shared singleton)
MERGE (lm_praise:LiteralMeaning { value: "praise" })
  SET lm_praise.name = "Praise",
      lm_praise.description = "The surface meaning of the utterance is positive and complimentary.";

// IntendedMeanings
MERGE (im_sarcasm:IntendedMeaning { value: "sarcasm" })
  SET im_sarcasm.name = "Sarcasm",
      im_sarcasm.description = "The speaker intends the opposite of the literal meaning, implying criticism.";

MERGE (im_praise:IntendedMeaning { value: "praise" })
  SET im_praise.name = "Genuine Praise",
      im_praise.description = "The speaker genuinely admires and compliments the subject.";

MERGE (im_compliment:IntendedMeaning { value: "compliment" })
  SET im_compliment.name = "Compliment",
      im_compliment.description = "A sincere positive remark directed at the subject.";

MERGE (im_indiff:IntendedMeaning { value: "indifference" })
  SET im_indiff.name = "Indifference",
      im_indiff.description = "The speaker is neutral or uninterested despite surface-level positive words.";

// ------------------------------------------------------------
// 2. Signal vocabulary nodes (shared, one per kind+valueId)
// ------------------------------------------------------------

MERGE (sig_lm_praise:Signal { kind: "literal_meaning", valueId: "praise" })
  SET sig_lm_praise.name = "Signal: literal_meaning=praise",
      sig_lm_praise.description = "Observed signal: the utterance has a literal meaning of praise.";

MERGE (sig_expr_roll:Signal { kind: "expression", valueId: "eye_roll" })
  SET sig_expr_roll.name = "Signal: expression=eye_roll",
      sig_expr_roll.description = "Observed signal: the speaker displays an eye-roll expression.";

MERGE (sig_expr_awe:Signal { kind: "expression", valueId: "awe" })
  SET sig_expr_awe.name = "Signal: expression=awe",
      sig_expr_awe.description = "Observed signal: the speaker displays an awe expression.";

MERGE (sig_tone_dry:Signal { kind: "tone", valueId: "dry_tone" })
  SET sig_tone_dry.name = "Signal: tone=dry_tone",
      sig_tone_dry.description = "Observed signal: the utterance is delivered in a dry tone.";

MERGE (sig_tone_enth:Signal { kind: "tone", valueId: "enthusiastic_tone" })
  SET sig_tone_enth.name = "Signal: tone=enthusiastic_tone",
      sig_tone_enth.description = "Observed signal: the utterance is delivered in an enthusiastic tone.";

MERGE (sig_ctx_painting:Signal { kind: "context", valueId: "They are looking at my painting" })
  SET sig_ctx_painting.name = "Signal: context=painting",
      sig_ctx_painting.description = "Observed signal: the context is that someone is looking at the painting.";

// Optional bridge: Context -> GENERATES_SIGNAL -> Signal
MATCH (ctx_painting:Context { value: "They are looking at my painting" })
MATCH (sig_ctx_painting:Signal { kind: "context", valueId: "They are looking at my painting" })
MERGE (ctx_painting)-[:GENERATES_SIGNAL]->(sig_ctx_painting);

// ------------------------------------------------------------
// 3. Statements
// ------------------------------------------------------------

MERGE (stmt_congrats:Statement { statementId: "stmt_congrats_original" })
  SET stmt_congrats.text = "Congratulations, it's definitely original";

MERGE (stmt_great:Statement { statementId: "stmt_great_original" })
  SET stmt_great.text = "It's great, it's very original";

// Statement -> HAS_LITERAL_MEANING -> LiteralMeaning
MATCH (stmt_congrats:Statement { statementId: "stmt_congrats_original" })
MATCH (lm_praise:LiteralMeaning { value: "praise" })
MERGE (stmt_congrats)-[:HAS_LITERAL_MEANING]->(lm_praise);

MATCH (stmt_great:Statement { statementId: "stmt_great_original" })
MATCH (lm_praise:LiteralMeaning { value: "praise" })
MERGE (stmt_great)-[:HAS_LITERAL_MEANING]->(lm_praise);

// Statement -> HAS_TONE -> Tone
MATCH (stmt_congrats:Statement { statementId: "stmt_congrats_original" })
MATCH (tone_dry:Tone { value: "dry_tone" })
MERGE (stmt_congrats)-[:HAS_TONE]->(tone_dry);

MATCH (stmt_great:Statement { statementId: "stmt_great_original" })
MATCH (tone_enth:Tone { value: "enthusiastic_tone" })
MERGE (stmt_great)-[:HAS_TONE]->(tone_enth);

// ------------------------------------------------------------
// 4. Person -> SAID -> Statement
// ------------------------------------------------------------

// Spec note: Situation A speaker is Henry (says the sarcastic line)
//            Situation B speaker is Alice (says the genuine praise)
MATCH (henry:Person { name: "Henry" })
MATCH (stmt_congrats:Statement { statementId: "stmt_congrats_original" })
MERGE (henry)-[:SAID]->(stmt_congrats);

MATCH (alice:Person { name: "Alice" })
MATCH (stmt_great:Statement { statementId: "stmt_great_original" })
MERGE (alice)-[:SAID]->(stmt_great);

// ------------------------------------------------------------
// 5. Person -> HAS_EXPRESSION -> Expression
// ------------------------------------------------------------

MATCH (henry:Person { name: "Henry" })
MATCH (expr_roll:Expression { value: "eye_roll" })
MERGE (henry)-[:HAS_EXPRESSION]->(expr_roll);

MATCH (alice:Person { name: "Alice" })
MATCH (expr_awe:Expression { value: "awe" })
MERGE (alice)-[:HAS_EXPRESSION]->(expr_awe);

// ------------------------------------------------------------
// 6. Situation A (Sarcasm)
// ------------------------------------------------------------

MERGE (sit_a:Situation { situationId: "situation_a" })
  SET sit_a.name = "Dry congratulations with eye roll",
      sit_a.description = "A person is looking at my painting and says 'Congratulations, it's definitely original' in a dry tone with an eye-roll expression.";

MATCH (sit_a:Situation { situationId: "situation_a" })
MATCH (henry:Person { name: "Henry" })
MERGE (sit_a)-[:HAS_SPEAKER]->(henry);

MATCH (sit_a:Situation { situationId: "situation_a" })
MATCH (stmt_congrats:Statement { statementId: "stmt_congrats_original" })
MERGE (sit_a)-[:HAS_STATEMENT]->(stmt_congrats);

MATCH (sit_a:Situation { situationId: "situation_a" })
MATCH (tone_dry:Tone { value: "dry_tone" })
MERGE (sit_a)-[:HAS_TONE]->(tone_dry);

MATCH (sit_a:Situation { situationId: "situation_a" })
MATCH (expr_roll:Expression { value: "eye_roll" })
MERGE (sit_a)-[:HAS_EXPRESSION]->(expr_roll);

MATCH (sit_a:Situation { situationId: "situation_a" })
MATCH (ctx_painting:Context { value: "They are looking at my painting" })
MERGE (sit_a)-[:HAS_CONTEXT]->(ctx_painting);

// Situation A -> HAS_SIGNAL -> Signal (derived signal set)
MATCH (sit_a:Situation { situationId: "situation_a" })
MATCH (sig_lm_praise:Signal { kind: "literal_meaning", valueId: "praise" })
MERGE (sit_a)-[:HAS_SIGNAL]->(sig_lm_praise);

MATCH (sit_a:Situation { situationId: "situation_a" })
MATCH (sig_expr_roll:Signal { kind: "expression", valueId: "eye_roll" })
MERGE (sit_a)-[:HAS_SIGNAL]->(sig_expr_roll);

MATCH (sit_a:Situation { situationId: "situation_a" })
MATCH (sig_tone_dry:Signal { kind: "tone", valueId: "dry_tone" })
MERGE (sit_a)-[:HAS_SIGNAL]->(sig_tone_dry);

MATCH (sit_a:Situation { situationId: "situation_a" })
MATCH (sig_ctx_painting:Signal { kind: "context", valueId: "They are looking at my painting" })
MERGE (sit_a)-[:HAS_SIGNAL]->(sig_ctx_painting);

// ------------------------------------------------------------
// 7. Situation B (Genuine Praise)
// ------------------------------------------------------------

MERGE (sit_b:Situation { situationId: "situation_b" })
  SET sit_b.name = "Enthusiastic praise with awe",
      sit_b.description = "A person is looking at my painting and says 'It's great, it's very original' in an enthusiastic tone with an expression of awe.";

MATCH (sit_b:Situation { situationId: "situation_b" })
MATCH (alice:Person { name: "Alice" })
MERGE (sit_b)-[:HAS_SPEAKER]->(alice);

MATCH (sit_b:Situation { situationId: "situation_b" })
MATCH (stmt_great:Statement { statementId: "stmt_great_original" })
MERGE (sit_b)-[:HAS_STATEMENT]->(stmt_great);

MATCH (sit_b:Situation { situationId: "situation_b" })
MATCH (tone_enth:Tone { value: "enthusiastic_tone" })
MERGE (sit_b)-[:HAS_TONE]->(tone_enth);

MATCH (sit_b:Situation { situationId: "situation_b" })
MATCH (expr_awe:Expression { value: "awe" })
MERGE (sit_b)-[:HAS_EXPRESSION]->(expr_awe);

MATCH (sit_b:Situation { situationId: "situation_b" })
MATCH (ctx_painting:Context { value: "They are looking at my painting" })
MERGE (sit_b)-[:HAS_CONTEXT]->(ctx_painting);

// Situation B -> HAS_SIGNAL -> Signal (derived signal set)
MATCH (sit_b:Situation { situationId: "situation_b" })
MATCH (sig_lm_praise:Signal { kind: "literal_meaning", valueId: "praise" })
MERGE (sit_b)-[:HAS_SIGNAL]->(sig_lm_praise);

MATCH (sit_b:Situation { situationId: "situation_b" })
MATCH (sig_expr_awe:Signal { kind: "expression", valueId: "awe" })
MERGE (sit_b)-[:HAS_SIGNAL]->(sig_expr_awe);

MATCH (sit_b:Situation { situationId: "situation_b" })
MATCH (sig_tone_enth:Signal { kind: "tone", valueId: "enthusiastic_tone" })
MERGE (sit_b)-[:HAS_SIGNAL]->(sig_tone_enth);

MATCH (sit_b:Situation { situationId: "situation_b" })
MATCH (sig_ctx_painting:Signal { kind: "context", valueId: "They are looking at my painting" })
MERGE (sit_b)-[:HAS_SIGNAL]->(sig_ctx_painting);

// ------------------------------------------------------------
// 8. Patterns
// ------------------------------------------------------------

// Pattern: Sarcasm (all_required, strict)
MERGE (pat_sarcasm:Pattern { patternId: "pattern_sarcasm" })
  SET pat_sarcasm.name = "Sarcasm Pattern",
      pat_sarcasm.description = "Praise is given with an eye roll and dry tone while looking at a painting — signals sarcasm.",
      pat_sarcasm.match_mode = "all_required";

// Pattern: Genuine Praise (all_required, strict)
MERGE (pat_praise:Pattern { patternId: "pattern_genuine_praise" })
  SET pat_praise.name = "Genuine Praise Pattern",
      pat_praise.description = "Praise is given with awe and enthusiastic tone while looking at a painting — signals genuine admiration.",
      pat_praise.match_mode = "all_required";

// Pattern REQUIRES Signal (with optional weight property, default 1.0)
MATCH (pat_sarcasm:Pattern { patternId: "pattern_sarcasm" })
MATCH (sig_lm_praise:Signal { kind: "literal_meaning", valueId: "praise" })
MERGE (pat_sarcasm)-[:REQUIRES { weight: 1.0 }]->(sig_lm_praise);

MATCH (pat_sarcasm:Pattern { patternId: "pattern_sarcasm" })
MATCH (sig_expr_roll:Signal { kind: "expression", valueId: "eye_roll" })
MERGE (pat_sarcasm)-[:REQUIRES { weight: 1.0 }]->(sig_expr_roll);

MATCH (pat_sarcasm:Pattern { patternId: "pattern_sarcasm" })
MATCH (sig_tone_dry:Signal { kind: "tone", valueId: "dry_tone" })
MERGE (pat_sarcasm)-[:REQUIRES { weight: 1.0 }]->(sig_tone_dry);

MATCH (pat_sarcasm:Pattern { patternId: "pattern_sarcasm" })
MATCH (sig_ctx_painting:Signal { kind: "context", valueId: "They are looking at my painting" })
MERGE (pat_sarcasm)-[:REQUIRES { weight: 1.0 }]->(sig_ctx_painting);

MATCH (pat_praise:Pattern { patternId: "pattern_genuine_praise" })
MATCH (sig_lm_praise:Signal { kind: "literal_meaning", valueId: "praise" })
MERGE (pat_praise)-[:REQUIRES { weight: 1.0 }]->(sig_lm_praise);

MATCH (pat_praise:Pattern { patternId: "pattern_genuine_praise" })
MATCH (sig_expr_awe:Signal { kind: "expression", valueId: "awe" })
MERGE (pat_praise)-[:REQUIRES { weight: 1.0 }]->(sig_expr_awe);

MATCH (pat_praise:Pattern { patternId: "pattern_genuine_praise" })
MATCH (sig_tone_enth:Signal { kind: "tone", valueId: "enthusiastic_tone" })
MERGE (pat_praise)-[:REQUIRES { weight: 1.0 }]->(sig_tone_enth);

MATCH (pat_praise:Pattern { patternId: "pattern_genuine_praise" })
MATCH (sig_ctx_painting:Signal { kind: "context", valueId: "They are looking at my painting" })
MERGE (pat_praise)-[:REQUIRES { weight: 1.0 }]->(sig_ctx_painting);

// Pattern PREDICTS IntendedMeaning (with probability on the relationship)
MATCH (pat_sarcasm:Pattern { patternId: "pattern_sarcasm" })
MATCH (im_sarcasm:IntendedMeaning { value: "sarcasm" })
MERGE (pat_sarcasm)-[:PREDICTS { probability: 0.8 }]->(im_sarcasm);

MATCH (pat_praise:Pattern { patternId: "pattern_genuine_praise" })
MATCH (im_praise:IntendedMeaning { value: "praise" })
MERGE (pat_praise)-[:PREDICTS { probability: 0.85 }]->(im_praise);

// ============================================================
// VALIDATION QUERIES (commented)
// ============================================================

// -- V1: Count all node labels --
// MATCH (n) RETURN labels(n) AS label, count(n) AS count ORDER BY label;

// -- V2: Verify both situations exist with correct names --
// MATCH (s:Situation) RETURN s.situationId, s.name ORDER BY s.situationId;

// -- V3: Verify each situation has exactly 4 signals --
// MATCH (s:Situation)-[:HAS_SIGNAL]->(sig:Signal)
// RETURN s.situationId, count(sig) AS signalCount;

// -- V4: Verify pattern signal requirements (4 per pattern) --
// MATCH (p:Pattern)-[:REQUIRES]->(sig:Signal)
// RETURN p.patternId, count(sig) AS requiredSignals;

// -- V5: Verify PREDICTS probabilities --
// MATCH (p:Pattern)-[r:PREDICTS]->(im:IntendedMeaning)
// RETURN p.patternId, im.value AS intendedMeaning, r.probability AS probability;

// -- V6: Strict pattern matching for Situation A (should fire sarcasm) --
// MATCH (sit:Situation { situationId: "situation_a" })
// MATCH (pat:Pattern { match_mode: "all_required" })
// WITH sit, pat,
//      [(pat)-[:REQUIRES]->(req) | req] AS required,
//      [(sit)-[:HAS_SIGNAL]->(sig) | sig] AS observed
// WHERE ALL(req IN required WHERE req IN observed)
// MATCH (pat)-[r:PREDICTS]->(im:IntendedMeaning)
// RETURN sit.situationId, pat.patternId, im.value AS intendedMeaning, r.probability AS probability;

// -- V7: Strict pattern matching for Situation B (should fire genuine praise) --
// MATCH (sit:Situation { situationId: "situation_b" })
// MATCH (pat:Pattern { match_mode: "all_required" })
// WITH sit, pat,
//      [(pat)-[:REQUIRES]->(req) | req] AS required,
//      [(sit)-[:HAS_SIGNAL]->(sig) | sig] AS observed
// WHERE ALL(req IN required WHERE req IN observed)
// MATCH (pat)-[r:PREDICTS]->(im:IntendedMeaning)
// RETURN sit.situationId, pat.patternId, im.value AS intendedMeaning, r.probability AS probability;

// -- V8: Verify shared LiteralMeaning singleton (both statements point to same node) --
// MATCH (st:Statement)-[:HAS_LITERAL_MEANING]->(lm:LiteralMeaning)
// RETURN st.statementId, st.text, lm.value;

// -- V9: Verify speaker assignments --
// MATCH (sit:Situation)-[:HAS_SPEAKER]->(p:Person)
// RETURN sit.situationId, p.name AS speaker;

// -- V10: Verify Context -> GENERATES_SIGNAL bridge --
// MATCH (ctx:Context)-[:GENERATES_SIGNAL]->(sig:Signal)
// RETURN ctx.value, sig.kind, sig.valueId;

// -- V11: Full situation profile (speaker, statement, tone, expression, context) --
// MATCH (sit:Situation)
// OPTIONAL MATCH (sit)-[:HAS_SPEAKER]->(p:Person)
// OPTIONAL MATCH (sit)-[:HAS_STATEMENT]->(st:Statement)
// OPTIONAL MATCH (sit)-[:HAS_TONE]->(t:Tone)
// OPTIONAL MATCH (sit)-[:HAS_EXPRESSION]->(e:Expression)
// OPTIONAL MATCH (sit)-[:HAS_CONTEXT]->(ctx:Context)
// RETURN sit.situationId, p.name, st.text, t.value, e.value, ctx.value
// ORDER BY sit.situationId;

// -- V12: Partial matching query (coverage-based, for future use) --
// MATCH (sit:Situation { situationId: "situation_a" })
// MATCH (pat:Pattern)
// WITH sit, pat,
//      [(pat)-[r:REQUIRES]->(req) | { sig: req, weight: coalesce(r.weight, 1.0) }] AS requiredWeighted,
//      [(sit)-[:H
