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

// Indexes for frequent lookups
CREATE INDEX signal_kind_value IF NOT EXISTS
  FOR (sig:Signal) ON (sig.kind, sig.valueId);

CREATE INDEX statement_text IF NOT EXISTS
  FOR (st:Statement) ON (st.text);

// ============================================================
// SAMPLE DATA LOAD
// ============================================================

// ------------------------------------------------------------
// 1. Vocabulary / base nodes
// ------------------------------------------------------------

// Persons
MERGE (alice:Person { name: "Alice" });
MERGE (henry:Person { name: "Henry" });

// Tones
MERGE (tone_annoyed:Tone { value: "annoyed_tone" });
MERGE (tone_warm:Tone    { value: "warm_tone" });

// Expressions
MERGE (expr_eye_roll:Expression { value: "eye_roll" });
MERGE (expr_smile:Expression    { value: "smile" });

// Contexts
MERGE (ctx_mistake:Context { value: "mistake_happened" });

// LiteralMeanings
MERGE (lm_praise:LiteralMeaning       { value: "praise" });
MERGE (lm_encouragement:LiteralMeaning { value: "encouragement" });

// IntendedMeanings
MERGE (im_sarcasm:IntendedMeaning      { value: "sarcasm" });
MERGE (im_criticism:IntendedMeaning    { value: "criticism" });
MERGE (im_encouragement:IntendedMeaning { value: "encouragement" });

// ------------------------------------------------------------
// 2. Shared Signal vocabulary nodes
//    signalId = kind + "__" + valueId  (stable, reusable)
// ------------------------------------------------------------

MERGE (sig_praise:Signal        { signalId: "literal_meaning__praise",
                                   kind: "literal_meaning",
                                   valueId: "praise" });

MERGE (sig_eye_roll:Signal      { signalId: "expression__eye_roll",
                                   kind: "expression",
                                   valueId: "eye_roll" });

MERGE (sig_smile:Signal         { signalId: "expression__smile",
                                   kind: "expression",
                                   valueId: "smile" });

MERGE (sig_annoyed:Signal       { signalId: "tone__annoyed_tone",
                                   kind: "tone",
                                   valueId: "annoyed_tone" });

MERGE (sig_warm:Signal          { signalId: "tone__warm_tone",
                                   kind: "tone",
                                   valueId: "warm_tone" });

MERGE (sig_mistake:Signal       { signalId: "context__mistake_happened",
                                   kind: "context",
                                   valueId: "mistake_happened" });

// Optional bridge: Context -> GENERATES_SIGNAL -> Signal
MATCH (ctx:Context  { value: "mistake_happened" }),
      (sig:Signal   { signalId: "context__mistake_happened" })
MERGE (ctx)-[:GENERATES_SIGNAL]->(sig);

// ------------------------------------------------------------
// 3. Patterns
// ------------------------------------------------------------

// Pattern A: Sarcasm
MERGE (pat_sarcasm:Pattern {
  patternId:   "pattern_sarcasm_mistake_praise_annoyed",
  description: "Praise words + annoyed tone + eye roll in mistake context suggests sarcasm"
});

// Pattern B: Genuine Encouragement
MERGE (pat_enc:Pattern {
  patternId:   "pattern_encouragement_mistake_praise_warm",
  description: "Praise words + warm tone + smile in mistake context suggests genuine encouragement"
});

// Pattern A REQUIRES signals
MATCH (pat:Pattern  { patternId: "pattern_sarcasm_mistake_praise_annoyed" }),
      (s1:Signal    { signalId:  "literal_meaning__praise" }),
      (s2:Signal    { signalId:  "expression__eye_roll" }),
      (s3:Signal    { signalId:  "tone__annoyed_tone" }),
      (s4:Signal    { signalId:  "context__mistake_happened" })
MERGE (pat)-[:REQUIRES]->(s1)
MERGE (pat)-[:REQUIRES]->(s2)
MERGE (pat)-[:REQUIRES]->(s3)
MERGE (pat)-[:REQUIRES]->(s4);

// Pattern A PREDICTS sarcasm with probability 0.8
MATCH (pat:Pattern       { patternId: "pattern_sarcasm_mistake_praise_annoyed" }),
      (im:IntendedMeaning { value:    "sarcasm" })
MERGE (pat)-[r:PREDICTS]->(im)
  ON CREATE SET r.probability = 0.8
  ON MATCH  SET r.probability = 0.8;

// Pattern B REQUIRES signals
MATCH (pat:Pattern  { patternId: "pattern_encouragement_mistake_praise_warm" }),
      (s1:Signal    { signalId:  "literal_meaning__praise" }),
      (s2:Signal    { signalId:  "expression__smile" }),
      (s3:Signal    { signalId:  "tone__warm_tone" }),
      (s4:Signal    { signalId:  "context__mistake_happened" })
MERGE (pat)-[:REQUIRES]->(s1)
MERGE (pat)-[:REQUIRES]->(s2)
MERGE (pat)-[:REQUIRES]->(s3)
MERGE (pat)-[:REQUIRES]->(s4);

// Pattern B PREDICTS encouragement with probability 0.85
MATCH (pat:Pattern       { patternId: "pattern_encouragement_mistake_praise_warm" }),
      (im:IntendedMeaning { value:    "encouragement" })
MERGE (pat)-[r:PREDICTS]->(im)
  ON CREATE SET r.probability = 0.85
  ON MATCH  SET r.probability = 0.85;

// ------------------------------------------------------------
// 4. Situation A — Sarcasm scenario
// ------------------------------------------------------------

// Statement instance for Situation A
MERGE (stmt_a:Statement { statementId: "stmt_great_job_a", text: "Great job" });

// Henry SAID the statement; Henry HAS_EXPRESSION eye_roll
MATCH (henry:Person    { name:  "Henry" }),
      (stmt_a:Statement { statementId: "stmt_great_job_a" }),
      (expr_er:Expression { value: "eye_roll" })
MERGE (henry)-[:SAID]->(stmt_a)
MERGE (henry)-[:HAS_EXPRESSION]->(expr_er);

// Statement A links
MATCH (stmt_a:Statement   { statementId: "stmt_great_job_a" }),
      (lm:LiteralMeaning  { value: "praise" }),
      (tone_an:Tone        { value: "annoyed_tone" })
MERGE (stmt_a)-[:HAS_LITERAL_MEANING]->(lm)
MERGE (stmt_a)-[:HAS_TONE]->(tone_an);

// Situation A node
MERGE (sit_a:Situation { situationId: "after_mistake_sarcasm",
                          name:        "after_mistake_sarcasm" });

// Situation A edges
MATCH (sit_a:Situation   { situationId: "after_mistake_sarcasm" }),
      (henry:Person       { name:  "Henry" }),
      (stmt_a:Statement   { statementId: "stmt_great_job_a" }),
      (tone_an:Tone        { value: "annoyed_tone" }),
      (expr_er:Expression  { value: "eye_roll" }),
      (ctx:Context         { value: "mistake_happened" })
MERGE (sit_a)-[:HAS_SPEAKER]->(henry)
MERGE (sit_a)-[:HAS_STATEMENT]->(stmt_a)
MERGE (sit_a)-[:HAS_TONE]->(tone_an)
MERGE (sit_a)-[:HAS_EXPRESSION]->(expr_er)
MERGE (sit_a)-[:HAS_CONTEXT]->(ctx);

// Attach derived signals to Situation A
MATCH (sit_a:Situation { situationId: "after_mistake_sarcasm" }),
      (s1:Signal { signalId: "literal_meaning__praise" }),
      (s2:Signal { signalId: "expression__eye_roll" }),
      (s3:Signal { signalId: "tone__annoyed_tone" }),
      (s4:Signal { signalId: "context__mistake_happened" })
MERGE (sit_a)-[:HAS_SIGNAL]->(s1)
MERGE (sit_a)-[:HAS_SIGNAL]->(s2)
MERGE (sit_a)-[:HAS_SIGNAL]->(s3)
MERGE (sit_a)-[:HAS_SIGNAL]->(s4);

// ------------------------------------------------------------
// 5. Situation B — Genuine Encouragement scenario
// ------------------------------------------------------------

// Statement instance for Situation B
MERGE (stmt_b:Statement { statementId: "stmt_great_job_b", text: "Great job" });

// Alice SAID the statement; Alice HAS_EXPRESSION smile
MATCH (alice:Person     { name:  "Alice" }),
      (stmt_b:Statement  { statementId: "stmt_great_job_b" }),
      (expr_sm:Expression { value: "smile" })
MERGE (alice)-[:SAID]->(stmt_b)
MERGE (alice)-[:HAS_EXPRESSION]->(expr_sm);

// Statement B links
MATCH (stmt_b:Statement   { statementId: "stmt_great_job_b" }),
      (lm:LiteralMeaning  { value: "praise" }),
      (tone_wm:Tone        { value: "warm_tone" })
MERGE (stmt_b)-[:HAS_LITERAL_MEANING]->(lm)
MERGE (stmt_b)-[:HAS_TONE]->(tone_wm);

// Situation B node
MERGE (sit_b:Situation { situationId: "after_mistake_encouragement",
                          name:        "after_mistake_encouragement" });

// Situation B edges
MATCH (sit_b:Situation   { situationId: "after_mistake_encouragement" }),
      (alice:Person        { name:  "Alice" }),
      (stmt_b:Statement    { statementId: "stmt_great_job_b" }),
      (tone_wm:Tone         { value: "warm_tone" }),
      (expr_sm:Expression   { value: "smile" }),
      (ctx:Context          { value: "mistake_happened" })
MERGE (sit_b)-[:HAS_SPEAKER]->(alice)
MERGE (sit_b)-[:HAS_STATEMENT]->(stmt_b)
MERGE (sit_b)-[:HAS_TONE]->(tone_wm)
MERGE (sit_b)-[:HAS_EXPRESSION]->(expr_sm)
MERGE (sit_b)-[:HAS_CONTEXT]->(ctx);

// Attach derived signals to Situation B
MATCH (sit_b:Situation { situationId: "after_mistake_encouragement" }),
      (s1:Signal { signalId: "literal_meaning__praise" }),
      (s2:Signal { signalId: "expression__smile" }),
      (s3:Signal { signalId: "tone__warm_tone" }),
      (s4:Signal { signalId: "context__mistake_happened" })
MERGE (sit_b)-[:HAS_SIGNAL]->(s1)
MERGE (sit_b)-[:HAS_SIGNAL]->(s2)
MERGE (sit_b)-[:HAS_SIGNAL]->(s3)
MERGE (sit_b)-[:HAS_SIGNAL]->(s4);

// ============================================================
// VALIDATION QUERIES  (run individually to inspect results)
// ============================================================

// -- V1: Count all node labels --
// MATCH (n) RETURN labels(n) AS label, count(n) AS total ORDER BY label;

// -- V2: Verify both persons exist --
// MATCH (p:Person) RETURN p.name ORDER BY p.name;

// -- V3: Verify all 6 Signal vocabulary nodes exist --
// MATCH (s:Signal) RETURN s.signalId, s.kind, s.valueId ORDER BY s.kind, s.valueId;

// -- V4: Verify both patterns and their REQUIRES edges --
// MATCH (pat:Pattern)-[:REQUIRES]->(sig:Signal)
// RETURN pat.patternId, collect(sig.signalId) AS requiredSignals
// ORDER BY pat.patternId;

// -- V5: Verify PREDICTS edges with probability --
// MATCH (pat:Pattern)-[r:PREDICTS]->(im:IntendedMeaning)
// RETURN pat.patternId, im.value AS intendedMeaning, r.probability AS probability
// ORDER BY pat.patternId;

// -- V6: Verify Situation A full subgraph --
// MATCH (sit:Situation { situationId: "after_mistake_sarcasm" })
// OPTIONAL MATCH (sit)-[:HAS_SPEAKER]->(p:Person)
// OPTIONAL MATCH (sit)-[:HAS_STATEMENT]->(st:Statement)
// OPTIONAL MATCH (sit)-[:HAS_TONE]->(t:Tone)
// OPTIONAL MATCH (sit)-[:HAS_EXPRESSION]->(e:Expression)
// OPTIONAL MATCH (sit)-[:HAS_CONTEXT]->(c:Context)
// RETURN sit.situationId, p.name, st.text, t.value, e.value, c.value;

// -- V7: Verify Situation B full subgraph --
// MATCH (sit:Situation { situationId: "after_mistake_encouragement" })
// OPTIONAL MATCH (sit)-[:HAS_SPEAKER]->(p:Person)
// OPTIONAL MATCH (sit)-[:HAS_STATEMENT]->(st:Statement)
// OPTIONAL MATCH (sit)-[:HAS_TONE]->(t:Tone)
// OPTIONAL MATCH (sit)-[:HAS_EXPRESSION]->(e:Expression)
// OPTIONAL MATCH (sit)-[:HAS_CONTEXT]->(c:Context)
// RETURN sit.situationId, p.name, st.text, t.value, e.value, c.value;

// -- V8: Pattern matching — fire patterns for Situation A --
// MATCH (sit:Situation { situationId: "after_mistake_sarcasm" })
// MATCH (pat:Pattern)-[:REQUIRES]->(reqSig:Signal)
// WITH sit, pat, collect(reqSig.signalId) AS required
// MATCH (sit)-[:HAS_SIGNAL]->(hasSig:Signal)
// WITH sit, pat, required, collect(hasSig.signalId) AS present
// WHERE ALL(r IN required WHERE r IN present)
// MATCH (pat)-[pred:PREDICTS]->(im:IntendedMeaning)
// RETURN sit.situationId, pat.patternId, im.value AS intendedMeaning, pred.probability;

// -- V9: Pattern matching — fire patterns for Situation B --
// MATCH (sit:Situation { situationId: "after_mistake_encouragement" })
// MATCH (pat:Pattern)-[:REQUIRES]->(reqSig:Signal)
// WITH sit, pat, collect(reqSig.signalId) AS required
// MATCH (sit)-[:HAS_SIGNAL]->(hasSig:Signal)
// WITH sit, pat, required, collect(hasSig.signalId) AS present
// WHERE ALL(r IN required WHERE r IN present)
// MATCH (pat)-[pred:PREDICTS]->(im:IntendedMeaning)
// RETURN sit.situationId, pat.patternId, im.value AS intendedMeaning, pred.probability;

// -- V10: Confirm same literal meaning shared across both situations --
// MATCH (lm:LiteralMeaning { value: "praise" })<-[:HAS_LITERAL_MEANING]-(st:Statement)
// RETURN lm.value AS sharedLiteralMeaning, collect(st.statementId) AS statements;

// -- V11: Context GENERATES_SIGNAL bridge --
// MATCH (ctx:Context)-[:GENERATES_SIGNAL]->(sig:Signal)
// RETURN ctx.value, sig.signalId;

