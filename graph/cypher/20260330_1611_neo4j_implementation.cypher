// ============================================================
// CONSTRAINTS AND INDEXES
// ============================================================

// Uniqueness constraints for stable-identifier node types
CREATE CONSTRAINT person_name_unique IF NOT EXISTS
  FOR (p:Person) REQUIRE p.name IS UNIQUE;

CREATE CONSTRAINT tone_value_unique IF NOT EXISTS
  FOR (t:Tone) REQUIRE t.value IS UNIQUE;

CREATE CONSTRAINT expression_value_unique IF NOT EXISTS
  FOR (e:Expression) REQUIRE e.value IS UNIQUE;

CREATE CONSTRAINT context_value_unique IF NOT EXISTS
  FOR (c:Context) REQUIRE c.value IS UNIQUE;

CREATE CONSTRAINT literal_meaning_value_unique IF NOT EXISTS
  FOR (lm:LiteralMeaning) REQUIRE lm.value IS UNIQUE;

CREATE CONSTRAINT intended_meaning_value_unique IF NOT EXISTS
  FOR (im:IntendedMeaning) REQUIRE im.value IS UNIQUE;

CREATE CONSTRAINT situation_id_unique IF NOT EXISTS
  FOR (s:Situation) REQUIRE s.situationId IS UNIQUE;

CREATE CONSTRAINT pattern_id_unique IF NOT EXISTS
  FOR (p:Pattern) REQUIRE p.patternId IS UNIQUE;

CREATE CONSTRAINT signal_id_unique IF NOT EXISTS
  FOR (sig:Signal) REQUIRE sig.signalId IS UNIQUE;

CREATE CONSTRAINT statement_id_unique IF NOT EXISTS
  FOR (st:Statement) REQUIRE st.statementId IS UNIQUE;

// Indexes for frequent lookups
CREATE INDEX signal_kind_value IF NOT EXISTS
  FOR (sig:Signal) ON (sig.kind, sig.valueId);

CREATE INDEX pattern_match_mode IF NOT EXISTS
  FOR (p:Pattern) ON (p.match_mode);

// ============================================================
// SAMPLE DATA LOAD
// ============================================================

// ------------------------------------------------------------
// Vocabulary / singleton nodes
// ------------------------------------------------------------

// Persons
MERGE (alice:Person { name: "Alice" });
MERGE (henry:Person { name: "Henry" });

// Tones
MERGE (tone_dry:Tone { value: "dry_tone" });
MERGE (tone_enth:Tone { value: "enthusiastic_tone" });

// Expressions
MERGE (expr_roll:Expression { value: "eye_roll" });
MERGE (expr_awe:Expression  { value: "awe" });

// Context (shared singleton)
MERGE (ctx_painting:Context { value: "They are looking at my painting" });

// LiteralMeaning (shared singleton)
MERGE (lm_praise:LiteralMeaning { value: "praise" });

// IntendedMeanings
MERGE (im_sarcasm:IntendedMeaning  { value: "sarcasm" });
MERGE (im_praise:IntendedMeaning   { value: "praise" });
MERGE (im_compliment:IntendedMeaning { value: "compliment" });
MERGE (im_indiff:IntendedMeaning   { value: "indifference" });

// ------------------------------------------------------------
// Signal vocabulary nodes (one per distinct kind+valueId pair)
// ------------------------------------------------------------

MERGE (sig_lm_praise:Signal    { signalId: "sig_lm_praise",    kind: "literal_meaning", valueId: "praise" });
MERGE (sig_expr_roll:Signal    { signalId: "sig_expr_roll",    kind: "expression",      valueId: "eye_roll" });
MERGE (sig_expr_awe:Signal     { signalId: "sig_expr_awe",     kind: "expression",      valueId: "awe" });
MERGE (sig_tone_dry:Signal     { signalId: "sig_tone_dry",     kind: "tone",            valueId: "dry_tone" });
MERGE (sig_tone_enth:Signal    { signalId: "sig_tone_enth",    kind: "tone",            valueId: "enthusiastic_tone" });
MERGE (sig_ctx_paint:Signal    { signalId: "sig_ctx_paint",    kind: "context",         valueId: "They are looking at my painting" });

// Context -> GENERATES_SIGNAL bridge
MATCH (ctx:Context  { value: "They are looking at my painting" })
MATCH (sig:Signal   { signalId: "sig_ctx_paint" })
MERGE (ctx)-[:GENERATES_SIGNAL]->(sig);

// ------------------------------------------------------------
// Pattern: Sarcasm
// ------------------------------------------------------------

MERGE (pat_sarcasm:Pattern {
  patternId:   "pattern_sarcasm",
  description: "Praise is given with a dry tone and eye roll while looking at a painting — suggests sarcasm",
  match_mode:  "all_required",
  min_coverage: 1.0
});

// Pattern REQUIRES signals
MATCH (pat:Pattern  { patternId: "pattern_sarcasm" })
MATCH (sig:Signal   { signalId: "sig_lm_praise" })
MERGE (pat)-[:REQUIRES { weight: 1.0 }]->(sig);

MATCH (pat:Pattern  { patternId: "pattern_sarcasm" })
MATCH (sig:Signal   { signalId: "sig_expr_roll" })
MERGE (pat)-[:REQUIRES { weight: 1.0 }]->(sig);

MATCH (pat:Pattern  { patternId: "pattern_sarcasm" })
MATCH (sig:Signal   { signalId: "sig_tone_dry" })
MERGE (pat)-[:REQUIRES { weight: 1.0 }]->(sig);

MATCH (pat:Pattern  { patternId: "pattern_sarcasm" })
MATCH (sig:Signal   { signalId: "sig_ctx_paint" })
MERGE (pat)-[:REQUIRES { weight: 1.0 }]->(sig);

// Pattern PREDICTS IntendedMeaning
MATCH (pat:Pattern       { patternId: "pattern_sarcasm" })
MATCH (im:IntendedMeaning { value: "sarcasm" })
MERGE (pat)-[:PREDICTS { probability: 0.8 }]->(im);

// ------------------------------------------------------------
// Pattern: Genuine Praise
// ------------------------------------------------------------

MERGE (pat_praise:Pattern {
  patternId:   "pattern_genuine_praise",
  description: "Praise is given with an enthusiastic tone and awe expression while looking at a painting — suggests genuine praise",
  match_mode:  "all_required",
  min_coverage: 1.0
});

// Pattern REQUIRES signals
MATCH (pat:Pattern  { patternId: "pattern_genuine_praise" })
MATCH (sig:Signal   { signalId: "sig_lm_praise" })
MERGE (pat)-[:REQUIRES { weight: 1.0 }]->(sig);

MATCH (pat:Pattern  { patternId: "pattern_genuine_praise" })
MATCH (sig:Signal   { signalId: "sig_expr_awe" })
MERGE (pat)-[:REQUIRES { weight: 1.0 }]->(sig);

MATCH (pat:Pattern  { patternId: "pattern_genuine_praise" })
MATCH (sig:Signal   { signalId: "sig_tone_enth" })
MERGE (pat)-[:REQUIRES { weight: 1.0 }]->(sig);

MATCH (pat:Pattern  { patternId: "pattern_genuine_praise" })
MATCH (sig:Signal   { signalId: "sig_ctx_paint" })
MERGE (pat)-[:REQUIRES { weight: 1.0 }]->(sig);

// Pattern PREDICTS IntendedMeaning
MATCH (pat:Pattern       { patternId: "pattern_genuine_praise" })
MATCH (im:IntendedMeaning { value: "praise" })
MERGE (pat)-[:PREDICTS { probability: 0.85 }]->(im);

// ------------------------------------------------------------
// Situation A — Sarcasm (Henry / eye_roll / dry_tone)
// ------------------------------------------------------------

MERGE (sit_a:Situation {
  situationId: "situation_a",
  name:        "painting_feedback_eye_roll"
});

// Statement (per-utterance instance)
MERGE (stmt_a:Statement {
  statementId: "stmt_congrats_original",
  text:        "Congratulations, it's definitely original"
});

// Core edges for Situation A
MATCH (henry:Person    { name: "Henry" })
MATCH (stmt_a:Statement { statementId: "stmt_congrats_original" })
MERGE (henry)-[:SAID]->(stmt_a);

MATCH (henry:Person    { name: "Henry" })
MATCH (expr:Expression { value: "eye_roll" })
MERGE (henry)-[:HAS_EXPRESSION]->(expr);

MATCH (stmt_a:Statement    { statementId: "stmt_congrats_original" })
MATCH (lm:LiteralMeaning   { value: "praise" })
MERGE (stmt_a)-[:HAS_LITERAL_MEANING]->(lm);

MATCH (stmt_a:Statement { statementId: "stmt_congrats_original" })
MATCH (tone:Tone        { value: "dry_tone" })
MERGE (stmt_a)-[:HAS_TONE]->(tone);

MATCH (sit_a:Situation { situationId: "situation_a" })
MATCH (henry:Person    { name: "Henry" })
MERGE (sit_a)-[:HAS_SPEAKER]->(henry);

MATCH (sit_a:Situation  { situationId: "situation_a" })
MATCH (stmt_a:Statement { statementId: "stmt_congrats_original" })
MERGE (sit_a)-[:HAS_STATEMENT]->(stmt_a);

MATCH (sit_a:Situation { situationId: "situation_a" })
MATCH (tone:Tone       { value: "dry_tone" })
MERGE (sit_a)-[:HAS_TONE]->(tone);

MATCH (sit_a:Situation { situationId: "situation_a" })
MATCH (expr:Expression { value: "eye_roll" })
MERGE (sit_a)-[:HAS_EXPRESSION]->(expr);

MATCH (sit_a:Situation { situationId: "situation_a" })
MATCH (ctx:Context     { value: "They are looking at my painting" })
MERGE (sit_a)-[:HAS_CONTEXT]->(ctx);

// Attach derived signals to Situation A
MATCH (sit_a:Situation { situationId: "situation_a" })
MATCH (sig:Signal      { signalId: "sig_lm_praise" })
MERGE (sit_a)-[:HAS_SIGNAL]->(sig);

MATCH (sit_a:Situation { situationId: "situation_a" })
MATCH (sig:Signal      { signalId: "sig_expr_roll" })
MERGE (sit_a)-[:HAS_SIGNAL]->(sig);

MATCH (sit_a:Situation { situationId: "situation_a" })
MATCH (sig:Signal      { signalId: "sig_tone_dry" })
MERGE (sit_a)-[:HAS_SIGNAL]->(sig);

MATCH (sit_a:Situation { situationId: "situation_a" })
MATCH (sig:Signal      { signalId: "sig_ctx_paint" })
MERGE (sit_a)-[:HAS_SIGNAL]->(sig);

// ------------------------------------------------------------
// Situation B — Genuine Praise (Alice / awe / enthusiastic_tone)
// ------------------------------------------------------------

MERGE (sit_b:Situation {
  situationId: "situation_b",
  name:        "painting_feedback_awe"
});

// Statement (per-utterance instance)
MERGE (stmt_b:Statement {
  statementId: "stmt_great_original",
  text:        "It's great, it's very original"
});

// Core edges for Situation B
MATCH (alice:Person    { name: "Alice" })
MATCH (stmt_b:Statement { statementId: "stmt_great_original" })
MERGE (alice)-[:SAID]->(stmt_b);

MATCH (alice:Person    { name: "Alice" })
MATCH (expr:Expression { value: "awe" })
MERGE (alice)-[:HAS_EXPRESSION]->(expr);

MATCH (stmt_b:Statement  { statementId: "stmt_great_original" })
MATCH (lm:LiteralMeaning { value: "praise" })
MERGE (stmt_b)-[:HAS_LITERAL_MEANING]->(lm);

MATCH (stmt_b:Statement { statementId: "stmt_great_original" })
MATCH (tone:Tone        { value: "enthusiastic_tone" })
MERGE (stmt_b)-[:HAS_TONE]->(tone);

MATCH (sit_b:Situation { situationId: "situation_b" })
MATCH (alice:Person    { name: "Alice" })
MERGE (sit_b)-[:HAS_SPEAKER]->(alice);

MATCH (sit_b:Situation  { situationId: "situation_b" })
MATCH (stmt_b:Statement { statementId: "stmt_great_original" })
MERGE (sit_b)-[:HAS_STATEMENT]->(stmt_b);

MATCH (sit_b:Situation { situationId: "situation_b" })
MATCH (tone:Tone       { value: "enthusiastic_tone" })
MERGE (sit_b)-[:HAS_TONE]->(tone);

MATCH (sit_b:Situation { situationId: "situation_b" })
MATCH (expr:Expression { value: "awe" })
MERGE (sit_b)-[:HAS_EXPRESSION]->(expr);

MATCH (sit_b:Situation { situationId: "situation_b" })
MATCH (ctx:Context     { value: "They are looking at my painting" })
MERGE (sit_b)-[:HAS_CONTEXT]->(ctx);

// Attach derived signals to Situation B
MATCH (sit_b:Situation { situationId: "situation_b" })
MATCH (sig:Signal      { signalId: "sig_lm_praise" })
MERGE (sit_b)-[:HAS_SIGNAL]->(sig);

MATCH (sit_b:Situation { situationId: "situation_b" })
MATCH (sig:Signal      { signalId: "sig_expr_awe" })
MERGE (sit_b)-[:HAS_SIGNAL]->(sig);

MATCH (sit_b:Situation { situationId: "situation_b" })
MATCH (sig:Signal      { signalId: "sig_tone_enth" })
MERGE (sit_b)-[:HAS_SIGNAL]->(sig);

MATCH (sit_b:Situation { situationId: "situation_b" })
MATCH (sig:Signal      { signalId: "sig_ctx_paint" })
MERGE (sit_b)-[:HAS_SIGNAL]->(sig);

// ============================================================
// VALIDATION QUERIES (commented out — run individually)
// ============================================================

// -- V1: Count all node labels
// MATCH (n)
// RETURN labels(n) AS label, count(n) AS total
// ORDER BY label;

// -- V2: Verify both situations exist with correct names
// MATCH (s:Situation)
// RETURN s.situationId, s.name
// ORDER BY s.situationId;

// -- V3: Verify each situation has exactly 4 signals attached
// MATCH (s:Situation)-[:HAS_SIGNAL]->(sig:Signal)
// RETURN s.situationId, count(sig) AS signal_count;

// -- V4: Verify patterns require exactly 4 signals each
// MATCH (p:Pattern)-[:REQUIRES]->(sig:Signal)
// RETURN p.patternId, count(sig) AS required_signal_count;

// -- V5: Verify PREDICTS probabilities
// MATCH (p:Pattern)-[r:PREDICTS]->(im:IntendedMeaning)
// RETURN p.patternId, im.value AS intended_meaning, r.probability AS probability
// ORDER BY p.patternId;

// -- V6: Pattern matching — fire patterns for Situation A
// MATCH (sit:Situation { situationId: "situation_a" })-[:HAS_SIGNAL]->(sig:Signal)
// WITH sit, collect(sig.signalId) AS situationSignals
// MATCH (pat:Pattern)-[:REQUIRES]->(req:Signal)
// WITH sit, situationSignals, pat, collect(req.signalId) AS requiredSignals
// WHERE all(r IN requiredSignals WHERE r IN situationSignals)
// MATCH (pat)-[pred:PREDICTS]->(im:IntendedMeaning)
// RETURN sit.situationId AS situation,
//        pat.patternId   AS fired_pattern,
//        im.value        AS intended_meaning,
//        pred.probability AS probability
// ORDER BY probability DESC;

// -- V7: Pattern matching — fire patterns for Situation B
// MATCH (sit:Situation { situationId: "situation_b" })-[:HAS_SIGNAL]->(sig:Signal)
// WITH sit, collect(sig.signalId) AS situationSignals
// MATCH (pat:Pattern)-[:REQUIRES]->(req:Signal)
// WITH sit, situationSignals, pat, collect(req.signalId) AS requiredSignals
// WHERE all(r IN requiredSignals WHERE r IN situationSignals)
// MATCH (pat)-[pred:PREDICTS]->(im:IntendedMeaning)
// RETURN sit.situationId AS situation,
//        pat.patternId   AS fired_pattern,
//        im.value        AS intended_meaning,
//        pred.probability AS probability
// ORDER BY probability DESC;

// -- V8: Verify shared LiteralMeaning singleton is reused by both statements
// MATCH (st:Statement)-[:HAS_LITERAL_MEANING]->(lm:LiteralMeaning)
// RETURN st.statementId, lm.value AS literal_meaning;

// -- V9: Verify Context GENERATES_SIGNAL bridge
// MATCH (ctx:Context)-[:GENERATES_SIGNAL]->(sig:Signal)
// RETURN ctx.value AS context, sig.signalId, sig.kind, sig.valueId;

// -- V10: Full situation summary — speaker, statement, tone, expression, context
// MATCH (sit:Situation)-[:HAS_SPEAKER]->(p:Person),
//       (sit)-[:HAS_STATEMENT]->(st:Statement),
//       (sit)-[:HAS_TONE]->(t:Tone),
//       (sit)-[:HAS_EXPRESSION]->(e:Expression),
//       (sit)-[:HAS_CONTEXT]->(ctx:Context)
// RETURN sit.situationId   AS situation,
//        p.name            AS speaker,
//        st.text           AS statement,
//        t.value           AS tone,
//        e.value           AS expression,
//        ctx.value         AS context
// ORDER BY sit.situationId;

