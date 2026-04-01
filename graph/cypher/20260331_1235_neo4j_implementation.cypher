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

// Statement uniqueness by statementId (NOT by text)
CREATE CONSTRAINT statement_id_unique IF NOT EXISTS
FOR (st:Statement) REQUIRE st.statementId IS UNIQUE;

// Signal uniqueness by composite key (kind + valueId)
CREATE CONSTRAINT signal_id_unique IF NOT EXISTS
FOR (sig:Signal) REQUIRE sig.signalId IS UNIQUE;

// Pattern uniqueness
CREATE CONSTRAINT pattern_id_unique IF NOT EXISTS
FOR (pat:Pattern) REQUIRE pat.patternId IS UNIQUE;

// Indexes for frequent lookups
CREATE INDEX signal_kind_value IF NOT EXISTS
FOR (sig:Signal) ON (sig.kind, sig.valueId);

CREATE INDEX statement_text IF NOT EXISTS
FOR (st:Statement) ON (st.text);

// ============================================================
// SAMPLE DATA LOAD
// ============================================================

// ------------------------------------------------------------
// Shared vocabulary nodes
// ------------------------------------------------------------

MERGE (alice:Person { name: "Alice" })
SET alice.description = "A person who gives genuine praise";

MERGE (henry:Person { name: "Henry" })
SET henry.description = "A person who speaks with sarcasm";

MERGE (tone_dry:Tone { value: "dry_tone" })
SET tone_dry.name = "Dry Tone";

MERGE (tone_enth:Tone { value: "enthusiastic_tone" })
SET tone_enth.name = "Enthusiastic Tone";

MERGE (expr_roll:Expression { value: "eye_roll" })
SET expr_roll.name = "Eye Roll";

MERGE (expr_awe:Expression { value: "awe" })
SET expr_awe.name = "Awe";

MERGE (ctx_painting:Context { value: "They are looking at my painting" })
SET ctx_painting.name = "Painting Context",
    ctx_painting.description = "The observer is looking at the speaker's painting";

MERGE (lm_praise:LiteralMeaning { value: "praise" })
SET lm_praise.name = "Praise",
    lm_praise.description = "The utterance literally expresses positive evaluation";

MERGE (im_sarcasm:IntendedMeaning { value: "sarcasm" })
SET im_sarcasm.name = "Sarcasm",
    im_sarcasm.description = "The speaker intends the opposite of the literal meaning, implying criticism";

MERGE (im_praise:IntendedMeaning { value: "praise" })
SET im_praise.name = "Genuine Praise",
    im_praise.description = "The speaker genuinely admires and compliments the painting";

MERGE (im_compliment:IntendedMeaning { value: "compliment" })
SET im_compliment.name = "Compliment";

MERGE (im_indifference:IntendedMeaning { value: "indifference" })
SET im_indifference.name = "Indifference";

// ------------------------------------------------------------
// Statement nodes (per-utterance instances, keyed by statementId)
// ------------------------------------------------------------

MERGE (stmt_congrats:Statement { statementId: "stmt_congrats_original" })
SET stmt_congrats.text = "Congratulations, it's definitely original",
    stmt_congrats.name  = "Congratulations statement";

MERGE (stmt_great:Statement { statementId: "stmt_great_original" })
SET stmt_great.text = "It's great, it's very original",
    stmt_great.name  = "Great statement";

// ------------------------------------------------------------
// Statement → vocabulary relationships
// ------------------------------------------------------------

MATCH (stmt_congrats:Statement { statementId: "stmt_congrats_original" })
MATCH (lm_praise:LiteralMeaning { value: "praise" })
MERGE (stmt_congrats)-[:HAS_LITERAL_MEANING]->(lm_praise);

MATCH (stmt_congrats:Statement { statementId: "stmt_congrats_original" })
MATCH (tone_dry:Tone { value: "dry_tone" })
MERGE (stmt_congrats)-[:HAS_TONE]->(tone_dry);

MATCH (stmt_great:Statement { statementId: "stmt_great_original" })
MATCH (lm_praise:LiteralMeaning { value: "praise" })
MERGE (stmt_great)-[:HAS_LITERAL_MEANING]->(lm_praise);

MATCH (stmt_great:Statement { statementId: "stmt_great_original" })
MATCH (tone_enth:Tone { value: "enthusiastic_tone" })
MERGE (stmt_great)-[:HAS_TONE]->(tone_enth);

// ------------------------------------------------------------
// Person → Statement (SAID)
// ------------------------------------------------------------

MATCH (henry:Person { name: "Henry" })
MATCH (stmt_congrats:Statement { statementId: "stmt_congrats_original" })
MERGE (henry)-[:SAID]->(stmt_congrats);

MATCH (alice:Person { name: "Alice" })
MATCH (stmt_great:Statement { statementId: "stmt_great_original" })
MERGE (alice)-[:SAID]->(stmt_great);

// ------------------------------------------------------------
// Person → Expression (HAS_EXPRESSION)
// ------------------------------------------------------------

MATCH (henry:Person { name: "Henry" })
MATCH (expr_roll:Expression { value: "eye_roll" })
MERGE (henry)-[:HAS_EXPRESSION]->(expr_roll);

MATCH (alice:Person { name: "Alice" })
MATCH (expr_awe:Expression { value: "awe" })
MERGE (alice)-[:HAS_EXPRESSION]->(expr_awe);

// ------------------------------------------------------------
// Signal nodes (shared singletons, keyed by kind+valueId)
// ------------------------------------------------------------

MERGE (sig_lm_praise:Signal { signalId: "signal_literal_meaning_praise" })
SET sig_lm_praise.kind    = "literal_meaning",
    sig_lm_praise.valueId = "praise",
    sig_lm_praise.name    = "Literal meaning: praise";

MERGE (sig_expr_roll:Signal { signalId: "signal_expression_eye_roll" })
SET sig_expr_roll.kind    = "expression",
    sig_expr_roll.valueId = "eye_roll",
    sig_expr_roll.name    = "Expression: eye_roll";

MERGE (sig_expr_awe:Signal { signalId: "signal_expression_awe" })
SET sig_expr_awe.kind    = "expression",
    sig_expr_awe.valueId = "awe",
    sig_expr_awe.name    = "Expression: awe";

MERGE (sig_tone_dry:Signal { signalId: "signal_tone_dry_tone" })
SET sig_tone_dry.kind    = "tone",
    sig_tone_dry.valueId = "dry_tone",
    sig_tone_dry.name    = "Tone: dry_tone";

MERGE (sig_tone_enth:Signal { signalId: "signal_tone_enthusiastic_tone" })
SET sig_tone_enth.kind    = "tone",
    sig_tone_enth.valueId = "enthusiastic_tone",
    sig_tone_enth.name    = "Tone: enthusiastic_tone";

MERGE (sig_ctx_painting:Signal { signalId: "signal_context_painting" })
SET sig_ctx_painting.kind    = "context",
    sig_ctx_painting.valueId = "They are looking at my painting",
    sig_ctx_painting.name    = "Context: painting";

// ------------------------------------------------------------
// Context → Signal bridge (GENERATES_SIGNAL)
// ------------------------------------------------------------

MATCH (ctx_painting:Context { value: "They are looking at my painting" })
MATCH (sig_ctx_painting:Signal { signalId: "signal_context_painting" })
MERGE (ctx_painting)-[:GENERATES_SIGNAL]->(sig_ctx_painting);

// ------------------------------------------------------------
// Pattern nodes
// ------------------------------------------------------------

MERGE (pat_sarcasm:Pattern { patternId: "pattern_sarcasm" })
SET pat_sarcasm.name        = "Sarcasm Pattern",
    pat_sarcasm.description = "Praise is given with an eye roll and dry tone while looking at a painting — suggests sarcasm",
    pat_sarcasm.match_mode  = "all_required",
    pat_sarcasm.min_coverage = 1.0;

MERGE (pat_praise:Pattern { patternId: "pattern_genuine_praise" })
SET pat_praise.name        = "Genuine Praise Pattern",
    pat_praise.description = "Praise is given with awe and enthusiastic tone while looking at a painting — suggests genuine praise",
    pat_praise.match_mode  = "all_required",
    pat_praise.min_coverage = 1.0;

// ------------------------------------------------------------
// Pattern → REQUIRES → Signal (with optional weight)
// ------------------------------------------------------------

MATCH (pat_sarcasm:Pattern { patternId: "pattern_sarcasm" })
MATCH (sig_lm_praise:Signal { signalId: "signal_literal_meaning_praise" })
MERGE (pat_sarcasm)-[:REQUIRES { weight: 1.0 }]->(sig_lm_praise);

MATCH (pat_sarcasm:Pattern { patternId: "pattern_sarcasm" })
MATCH (sig_expr_roll:Signal { signalId: "signal_expression_eye_roll" })
MERGE (pat_sarcasm)-[:REQUIRES { weight: 1.0 }]->(sig_expr_roll);

MATCH (pat_sarcasm:Pattern { patternId: "pattern_sarcasm" })
MATCH (sig_tone_dry:Signal { signalId: "signal_tone_dry_tone" })
MERGE (pat_sarcasm)-[:REQUIRES { weight: 1.0 }]->(sig_tone_dry);

MATCH (pat_sarcasm:Pattern { patternId: "pattern_sarcasm" })
MATCH (sig_ctx_painting:Signal { signalId: "signal_context_painting" })
MERGE (pat_sarcasm)-[:REQUIRES { weight: 1.0 }]->(sig_ctx_painting);

MATCH (pat_praise:Pattern { patternId: "pattern_genuine_praise" })
MATCH (sig_lm_praise:Signal { signalId: "signal_literal_meaning_praise" })
MERGE (pat_praise)-[:REQUIRES { weight: 1.0 }]->(sig_lm_praise);

MATCH (pat_praise:Pattern { patternId: "pattern_genuine_praise" })
MATCH (sig_expr_awe:Signal { signalId: "signal_expression_awe" })
MERGE (pat_praise)-[:REQUIRES { weight: 1.0 }]->(sig_expr_awe);

MATCH (pat_praise:Pattern { patternId: "pattern_genuine_praise" })
MATCH (sig_tone_enth:Signal { signalId: "signal_tone_enthusiastic_tone" })
MERGE (pat_praise)-[:REQUIRES { weight: 1.0 }]->(sig_tone_enth);

MATCH (pat_praise:Pattern { patternId: "pattern_genuine_praise" })
MATCH (sig_ctx_painting:Signal { signalId: "signal_context_painting" })
MERGE (pat_praise)-[:REQUIRES { weight: 1.0 }]->(sig_ctx_painting);

// ------------------------------------------------------------
// Pattern → PREDICTS → IntendedMeaning (with probability)
// ------------------------------------------------------------

MATCH (pat_sarcasm:Pattern { patternId: "pattern_sarcasm" })
MATCH (im_sarcasm:IntendedMeaning { value: "sarcasm" })
MERGE (pat_sarcasm)-[:PREDICTS { probability: 0.8 }]->(im_sarcasm);

MATCH (pat_praise:Pattern { patternId: "pattern_genuine_praise" })
MATCH (im_praise:IntendedMeaning { value: "praise" })
MERGE (pat_praise)-[:PREDICTS { probability: 0.85 }]->(im_praise);

// ------------------------------------------------------------
// Situation A — Sarcasm (Henry, dry tone, eye roll)
// ------------------------------------------------------------

MERGE (sit_a:Situation { situationId: "situation_a" })
SET sit_a.name        = "Dry congratulations with eye roll",
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

// Attach derived signals for Situation A
MATCH (sit_a:Situation { situationId: "situation_a" })
MATCH (sig_lm_praise:Signal { signalId: "signal_literal_meaning_praise" })
MERGE (sit_a)-[:HAS_SIGNAL]->(sig_lm_praise);

MATCH (sit_a:Situation { situationId: "situation_a" })
MATCH (sig_expr_roll:Signal { signalId: "signal_expression_eye_roll" })
MERGE (sit_a)-[:HAS_SIGNAL]->(sig_expr_roll);

MATCH (sit_a:Situation { situationId: "situation_a" })
MATCH (sig_tone_dry:Signal { signalId: "signal_tone_dry_tone" })
MERGE (sit_a)-[:HAS_SIGNAL]->(sig_tone_dry);

MATCH (sit_a:Situation { situationId: "situation_a" })
MATCH (sig_ctx_painting:Signal { signalId: "signal_context_painting" })
MERGE (sit_a)-[:HAS_SIGNAL]->(sig_ctx_painting);

// ------------------------------------------------------------
// Situation B — Genuine Praise (Alice, enthusiastic tone, awe)
// ------------------------------------------------------------

MERGE (sit_b:Situation { situationId: "situation_b" })
SET sit_b.name        = "Enthusiastic praise with awe",
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

// Attach derived signals for Situation B
MATCH (sit_b:Situation { situationId: "situation_b" })
MATCH (sig_lm_praise:Signal { signalId: "signal_literal_meaning_praise" })
MERGE (sit_b)-[:HAS_SIGNAL]->(sig_lm_praise);

MATCH (sit_b:Situation { situationId: "situation_b" })
MATCH (sig_expr_awe:Signal { signalId: "signal_expression_awe" })
MERGE (sit_b)-[:HAS_SIGNAL]->(sig_expr_awe);

MATCH (sit_b:Situation { situationId: "situation_b" })
MATCH (sig_tone_enth:Signal { signalId: "signal_tone_enthusiastic_tone" })
MERGE (sit_b)-[:HAS_SIGNAL]->(sig_tone_enth);

MATCH (sit_b:Situation { situationId: "situation_b" })
MATCH (sig_ctx_painting:Signal { signalId: "signal_context_painting" })
MERGE (sit_b)-[:HAS_SIGNAL]->(sig_ctx_painting);

// ============================================================
// VALIDATION QUERIES (commented out — run individually)
// ============================================================

// -- V1: Count all node labels
// MATCH (n) RETURN labels(n) AS label, count(n) AS total ORDER BY label;

// -- V2: Verify both situations exist with correct names
// MATCH (s:Situation) RETURN s.situationId, s.name ORDER BY s.situationId;

// -- V3: Verify each situation has exactly 4 signals attached
// MATCH (s:Situation)-[:HAS_SIGNAL]->(sig:Signal)
// RETURN s.situationId, count(sig) AS signal_count;

// -- V4: Verify each pattern requires exactly 4 signals
// MATCH (p:Pattern)-[:REQUIRES]->(sig:Signal)
// RETURN p.patternId, count(sig) AS required_signals;

// -- V5: Verify PREDICTS probabilities
// MATCH (p:Pattern)-[r:PREDICTS]->(im:IntendedMeaning)
// RETURN p.patternId, im.value AS intended_meaning, r.probability AS probability;

// -- V6: Pattern matching — find which patterns fire for Situation A
// MATCH (sit:Situation { situationId: "situation_a" })-[:HAS_SIGNAL]->(sig:Signal)
// WITH sit, collect(sig.signalId) AS situationSignals
// MATCH (pat:Pattern)-[:REQUIRES]->(req:Signal)
// WITH sit, situationSignals, pat, collect(req.signalId) AS requiredSignals
// WHERE ALL(r IN requiredSignals WHERE r IN situationSignals)
// MATCH (pat)-[pred:PREDICTS]->(im:IntendedMeaning)
// RETURN sit.situationId, pat.patternId, im.value AS intendedMeaning, pred.probability AS probability;

// -- V7: Pattern matching — find which patterns fire for Situation B
// MATCH (sit:Situation { situationId: "situation_b" })-[:HAS_SIGNAL]->(sig:Signal)
// WITH sit, collect(sig.signalId) AS situationSignals
// MATCH (pat:Pattern)-[:REQUIRES]->(req:Signal)
// WITH sit, situationSignals, pat, collect(req.signalId) AS requiredSignals
// WHERE ALL(r IN requiredSignals WHERE r IN situationSignals)
// MATCH (pat)-[pred:PREDICTS]->(im:IntendedMeaning)
// RETURN sit.situationId, pat.patternId, im.value AS intendedMeaning, pred.probability AS probability;

// -- V8: Full situation trace for Situation A (speaker, statement, tone, expression, context)
// MATCH (sit:Situation { situationId: "situation_a" })
// MATCH (sit)-[:HAS_SPEAKER]->(p:Person)
// MATCH (sit)-[:HAS_STATEMENT]->(st:Statement)
// MATCH (sit)-[:HAS_TONE]->(t:Tone)
// MATCH (sit)-[:HAS_EXPRESSION]->(e:Expression)
// MATCH (sit)-[:HAS_CONTEXT]->(c:Context)
// RETURN sit.name, p.name AS speaker, st.text AS statement,
//        t.value AS tone, e.value AS expression, c.value AS context;

// -- V9: Verify LiteralMeaning shared singleton is reused by both statements
// MATCH (st:Statement)-[:HAS_LITERAL_MEANING]->(lm:LiteralMeaning)
// RETURN st.statementId, st.text, lm.value AS literalMeaning;

// -- V10: Verify Context GENERATES_SIGNAL bridge
// MATCH (c:Context)-[:GENERATES_SIGNAL]->(sig:Signal)
// RETURN c.value AS context, sig.kind, sig.valueId;

// -- V11: Partial match coverage for all patterns against all situations
// MATCH (sit:Situation)-[:HAS_SIGNAL]->(sig:Signal)
// WITH sit, collect(sig.signalId) AS situationSignals
// MATCH (pat:Pattern)-[req_rel:REQUIRES]->(req:Signal)
// WITH sit, situationSignals, pat,
//      collect({ signalId: req.signalId, weight: coalesce(req_rel.weight, 1.0) }) AS requiredWithWeights
// WITH sit, pat, situationSignals, requiredWithWeights,
//      reduce(totalW = 0.0, r IN requiredWithWeights | totalW + r.weight) AS totalWeight,
//      reduce(obsW = 0.0, r IN requiredWithWeights |
//        obsW + CASE WHEN r.signalId IN situationSignals THEN r.weight ELSE 0.0 END) AS observedWeight
// WITH sit, pat, totalWeight, observedWeight,
//      CASE WHEN totalWeight > 0 THEN observedWeight / totalWeight ELSE 0.0 END AS coverage
// MATCH (pat)-[pred:PREDICTS]->(im:IntendedMeaning)
// RETURN sit.situationId, pat.patternId, im.value AS intendedMeaning,
//        round(coverage * 100) / 100 AS coverage,
//        pred.probability AS baseProbability,

