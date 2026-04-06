// ============================================================
// CONSTRAINTS AND INDEXES
// ============================================================

CREATE CONSTRAINT person_name_unique IF NOT EXISTS
FOR (p:Person) REQUIRE p.name IS UNIQUE;

CREATE CONSTRAINT statement_id_unique IF NOT EXISTS
FOR (s:Statement) REQUIRE s.statementId IS UNIQUE;

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

CREATE CONSTRAINT signal_type_id_unique IF NOT EXISTS
FOR (st:SignalType) REQUIRE st.signalTypeId IS UNIQUE;

CREATE CONSTRAINT situation_signal_id_unique IF NOT EXISTS
FOR (ss:SituationSignal) REQUIRE ss.situationSignalId IS UNIQUE;

CREATE CONSTRAINT pattern_id_unique IF NOT EXISTS
FOR (p:Pattern) REQUIRE p.patternId IS UNIQUE;

CREATE INDEX signal_type_kind_value IF NOT EXISTS
FOR (st:SignalType) ON (st.kind, st.valueId);

CREATE INDEX situation_signal_scope IF NOT EXISTS
FOR (ss:SituationSignal) ON (ss.situationId, ss.kind, ss.valueId);

// ============================================================
// SHARED VOCABULARY — SignalType nodes
// ============================================================

MERGE (st:SignalType {signalTypeId: 'st_tone_dry'})
  SET st.kind = 'tone',
      st.valueId = 'dry_tone',
      st.name = 'Dry Tone';

MERGE (st:SignalType {signalTypeId: 'st_tone_enthusiastic'})
  SET st.kind = 'tone',
      st.valueId = 'enthusiastic_tone',
      st.name = 'Enthusiastic Tone';

MERGE (st:SignalType {signalTypeId: 'st_expr_eye_roll'})
  SET st.kind = 'expression',
      st.valueId = 'eye_roll',
      st.name = 'Eye Roll';

MERGE (st:SignalType {signalTypeId: 'st_expr_awe'})
  SET st.kind = 'expression',
      st.valueId = 'awe',
      st.name = 'Awe';

MERGE (st:SignalType {signalTypeId: 'st_ctx_painting'})
  SET st.kind = 'context',
      st.valueId = 'They are looking at my painting',
      st.name = 'Painting Context';

MERGE (st:SignalType {signalTypeId: 'st_lm_praise'})
  SET st.kind = 'literal_meaning',
      st.valueId = 'praise',
      st.name = 'Literal Praise';

// ============================================================
// SHARED VOCABULARY — LiteralMeaning (singleton)
// ============================================================

MERGE (lm:LiteralMeaning {value: 'praise'})
  SET lm.name = 'Praise',
      lm.description = 'Surface-level complimentary meaning of the utterance';

// ============================================================
// SHARED VOCABULARY — Context (singleton)
// ============================================================

MERGE (ctx:Context {value: 'They are looking at my painting'})
  SET ctx.name = 'Painting Viewing Context',
      ctx.description = 'The observer is looking at the speaker\'s painting';

// ============================================================
// SHARED VOCABULARY — IntendedMeaning nodes
// ============================================================

MERGE (im:IntendedMeaning {value: 'sarcasm'})
  SET im.name = 'Sarcasm',
      im.description = 'The speaker intends the opposite of what is literally said, implying criticism';

MERGE (im:IntendedMeaning {value: 'indifference'})
  SET im.name = 'Indifference',
      im.description = 'The speaker is not genuinely engaged or invested';

MERGE (im:IntendedMeaning {value: 'compliment'})
  SET im.name = 'Compliment',
      im.description = 'The speaker offers a polite positive remark';

MERGE (im:IntendedMeaning {value: 'praise'})
  SET im.name = 'Genuine Praise',
      im.description = 'The speaker genuinely and enthusiastically admires the subject';

// ============================================================
// SHARED VOCABULARY — Tone nodes
// ============================================================

MERGE (t:Tone {value: 'dry_tone'})
  SET t.name = 'Dry Tone',
      t.description = 'A flat, deadpan delivery that signals detachment or sarcasm';

MERGE (t:Tone {value: 'enthusiastic_tone'})
  SET t.name = 'Enthusiastic Tone',
      t.description = 'An energetic, warm delivery that signals genuine positive feeling';

// ============================================================
// SHARED VOCABULARY — Expression nodes
// ============================================================

MERGE (e:Expression {value: 'eye_roll'})
  SET e.name = 'Eye Roll',
      e.description = 'A facial gesture signalling contempt, disbelief, or sarcasm';

MERGE (e:Expression {value: 'awe'})
  SET e.name = 'Awe',
      e.description = 'A facial expression of wonder and genuine admiration';

// ============================================================
// PATTERNS
// ============================================================

MERGE (p:Pattern {patternId: 'pattern_sarcasm'})
  SET p.name = 'Sarcasm Pattern',
      p.description = 'Praise given with a dry tone and eye roll in a painting context suggests sarcasm',
      p.match_mode = 'all_required',
      p.min_coverage = 1.0;

MERGE (p:Pattern {patternId: 'pattern_genuine_praise'})
  SET p.name = 'Genuine Praise Pattern',
      p.description = 'Praise given with an enthusiastic tone and awe expression in a painting context suggests genuine admiration',
      p.match_mode = 'all_required',
      p.min_coverage = 1.0;

// ============================================================
// PATTERN → REQUIRES → SignalType  (sarcasm pattern)
// ============================================================

MATCH (p:Pattern {patternId: 'pattern_sarcasm'})
MATCH (st:SignalType {signalTypeId: 'st_lm_praise'})
MERGE (p)-[:REQUIRES {weight: 1.0}]->(st);

MATCH (p:Pattern {patternId: 'pattern_sarcasm'})
MATCH (st:SignalType {signalTypeId: 'st_expr_eye_roll'})
MERGE (p)-[:REQUIRES {weight: 1.0}]->(st);

MATCH (p:Pattern {patternId: 'pattern_sarcasm'})
MATCH (st:SignalType {signalTypeId: 'st_tone_dry'})
MERGE (p)-[:REQUIRES {weight: 1.0}]->(st);

MATCH (p:Pattern {patternId: 'pattern_sarcasm'})
MATCH (st:SignalType {signalTypeId: 'st_ctx_painting'})
MERGE (p)-[:REQUIRES {weight: 1.0}]->(st);

// ============================================================
// PATTERN → PREDICTS → IntendedMeaning  (sarcasm pattern)
// ============================================================

MATCH (p:Pattern {patternId: 'pattern_sarcasm'})
MATCH (im:IntendedMeaning {value: 'sarcasm'})
MERGE (p)-[:PREDICTS {probability: 0.8}]->(im);

// ============================================================
// PATTERN → REQUIRES → SignalType  (genuine praise pattern)
// ============================================================

MATCH (p:Pattern {patternId: 'pattern_genuine_praise'})
MATCH (st:SignalType {signalTypeId: 'st_lm_praise'})
MERGE (p)-[:REQUIRES {weight: 1.0}]->(st);

MATCH (p:Pattern {patternId: 'pattern_genuine_praise'})
MATCH (st:SignalType {signalTypeId: 'st_expr_awe'})
MERGE (p)-[:REQUIRES {weight: 1.0}]->(st);

MATCH (p:Pattern {patternId: 'pattern_genuine_praise'})
MATCH (st:SignalType {signalTypeId: 'st_tone_enthusiastic'})
MERGE (p)-[:REQUIRES {weight: 1.0}]->(st);

MATCH (p:Pattern {patternId: 'pattern_genuine_praise'})
MATCH (st:SignalType {signalTypeId: 'st_ctx_painting'})
MERGE (p)-[:REQUIRES {weight: 1.0}]->(st);

// ============================================================
// PATTERN → PREDICTS → IntendedMeaning  (genuine praise pattern)
// ============================================================

MATCH (p:Pattern {patternId: 'pattern_genuine_praise'})
MATCH (im:IntendedMeaning {value: 'praise'})
MERGE (p)-[:PREDICTS {probability: 0.85}]->(im);

// ============================================================
// SITUATION A — Sarcasm
// ============================================================

// Situation node
MERGE (sit:Situation {situationId: 'painting_feedback_sarcasm'})
  SET sit.name = 'Painting Feedback — Sarcasm',
      sit.description = 'Alice looks at my painting and says Congratulations, it\'s definitely original in a dry tone with an eye-roll expression.';

// Person
MERGE (alice:Person {name: 'Alice'})
  SET alice.description = 'Speaker in the sarcasm scenario';

// Statement
MERGE (stmt_a:Statement {statementId: 'stmt_congrats'})
  SET stmt_a.text = 'Congratulations, it\'s definitely original',
      stmt_a.name = 'Congratulations statement';

// Tone (already created above; re-find only)
// Expression (already created above; re-find only)

// SituationSignal nodes for Situation A
MERGE (ss:SituationSignal {situationSignalId: 'sig_a_literal'})
  SET ss.situationId = 'painting_feedback_sarcasm',
      ss.kind = 'literal_meaning',
      ss.valueId = 'praise';

MERGE (ss:SituationSignal {situationSignalId: 'sig_a_expression'})
  SET ss.situationId = 'painting_feedback_sarcasm',
      ss.kind = 'expression',
      ss.valueId = 'eye_roll';

MERGE (ss:SituationSignal {situationSignalId: 'sig_a_tone'})
  SET ss.situationId = 'painting_feedback_sarcasm',
      ss.kind = 'tone',
      ss.valueId = 'dry_tone';

MERGE (ss:SituationSignal {situationSignalId: 'sig_a_context'})
  SET ss.situationId = 'painting_feedback_sarcasm',
      ss.kind = 'context',
      ss.valueId = 'They are looking at my painting';

// ---- Observational edges — Situation A ----

MATCH (sit:Situation {situationId: 'painting_feedback_sarcasm'})
MATCH (alice:Person {name: 'Alice'})
MERGE (sit)-[:HAS_SPEAKER]->(alice);

MATCH (sit:Situation {situationId: 'painting_feedback_sarcasm'})
MATCH (stmt_a:Statement {statementId: 'stmt_congrats'})
MERGE (sit)-[:HAS_STATEMENT]->(stmt_a);

MATCH (sit:Situation {situationId: 'painting_feedback_sarcasm'})
MATCH (t:Tone {value: 'dry_tone'})
MERGE (sit)-[:HAS_TONE]->(t);

MATCH (sit:Situation {situationId: 'painting_feedback_sarcasm'})
MATCH (e:Expression {value: 'eye_roll'})
MERGE (sit)-[:HAS_EXPRESSION]->(e);

MATCH (sit:Situation {situationId: 'painting_feedback_sarcasm'})
MATCH (ctx:Context {value: 'They are looking at my painting'})
MERGE (sit)-[:HAS_CONTEXT]->(ctx);

MATCH (alice:Person {name: 'Alice'})
MATCH (stmt_a:Statement {statementId: 'stmt_congrats'})
MERGE (alice)-[:SAID]->(stmt_a);

MATCH (alice:Person {name: 'Alice'})
MATCH (e:Expression {value: 'eye_roll'})
MERGE (alice)-[:HAS_EXPRESSION]->(e);

MATCH (stmt_a:Statement {statementId: 'stmt_congrats'})
MATCH (lm:LiteralMeaning {value: 'praise'})
MERGE (stmt_a)-[:HAS_LITERAL_MEANING]->(lm);

MATCH (stmt_a:Statement {statementId: 'stmt_congrats'})
MATCH (t:Tone {value: 'dry_tone'})
MERGE (stmt_a)-[:HAS_TONE]->(t);

// ---- Signal edges — Situation A ----

MATCH (sit:Situation {situationId: 'painting_feedback_sarcasm'})
MATCH (ss:SituationSignal {situationSignalId: 'sig_a_literal'})
MERGE (sit)-[:HAS_SIGNAL]->(ss);

MATCH (sit:Situation {situationId: 'painting_feedback_sarcasm'})
MATCH (ss:SituationSignal {situationSignalId: 'sig_a_expression'})
MERGE (sit)-[:HAS_SIGNAL]->(ss);

MATCH (sit:Situation {situationId: 'painting_feedback_sarcasm'})
MATCH (ss:SituationSignal {situationSignalId: 'sig_a_tone'})
MERGE (sit)-[:HAS_SIGNAL]->(ss);

MATCH (sit:Situation {situationId: 'painting_feedback_sarcasm'})
MATCH (ss:SituationSignal {situationSignalId: 'sig_a_context'})
MERGE (sit)-[:HAS_SIGNAL]->(ss);

MATCH (ss:SituationSignal {situationSignalId: 'sig_a_literal'})
MATCH (st:SignalType {signalTypeId: 'st_lm_praise'})
MERGE (ss)-[:INSTANCE_OF]->(st);

MATCH (ss:SituationSignal {situationSignalId: 'sig_a_expression'})
MATCH (st:SignalType {signalTypeId: 'st_expr_eye_roll'})
MERGE (ss)-[:INSTANCE_OF]->(st);

MATCH (ss:SituationSignal {situationSignalId: 'sig_a_tone'})
MATCH (st:SignalType {signalTypeId: 'st_tone_dry'})
MERGE (ss)-[:INSTANCE_OF]->(st);

MATCH (ss:SituationSignal {situationSignalId: 'sig_a_context'})
MATCH (st:SignalType {signalTypeId: 'st_ctx_painting'})
MERGE (ss)-[:INSTANCE_OF]->(st);

// ============================================================
// SITUATION B — Genuine Praise
// ============================================================

// Situation node
MERGE (sit:Situation {situationId: 'painting_feedback_genuine_praise'})
  SET sit.name = 'Painting Feedback — Genuine Praise',
      sit.description = 'Henry looks at my painting and says It\'s great, it\'s very original in an enthusiastic tone with an expression of awe.';

// Person
MERGE (henry:Person {name: 'Henry'})
  SET henry.description = 'Speaker in the genuine praise scenario';

// Statement
MERGE (stmt_b:Statement {statementId: 'stmt_great'})
  SET stmt_b.text = 'It\'s great, it\'s very original',
      stmt_b.name = 'Great statement';

// SituationSignal nodes for Situation B
MERGE (ss:SituationSignal {situationSignalId: 'sig_b_literal'})
  SET ss.situationId = 'painting_feedback_genuine_praise',
      ss.kind = 'literal_meaning',
      ss.valueId = 'praise';

MERGE (ss:SituationSignal {situationSignalId: 'sig_b_expression'})
  SET ss.situationId = 'painting_feedback_genuine_praise',
      ss.kind = 'expression',
      ss.valueId = 'awe';

MERGE (ss:SituationSignal {situationSignalId: 'sig_b_tone'})
  SET ss.situationId = 'painting_feedback_genuine_praise',
      ss.kind = 'tone',
      ss.valueId = 'enthusiastic_tone';

MERGE (ss:SituationSignal {situationSignalId: 'sig_b_context'})
  SET ss.situationId = 'painting_feedback_genuine_praise',
      ss.kind = 'context',
      ss.valueId = 'They are looking at my painting';

// ---- Observational edges — Situation B ----

MATCH (sit:Situation {situationId: 'painting_feedback_genuine_praise'})
MATCH (henry:Person {name: 'Henry'})
MERGE (sit)-[:HAS_SPEAKER]->(henry);

MATCH (sit:Situation {situationId: 'painting_feedback_genuine_praise'})
MATCH (stmt_b:Statement {statementId: 'stmt_great'})
MERGE (sit)-[:HAS_STATEMENT]->(stmt_b);

MATCH (sit:Situation {situationId: 'painting_feedback_genuine_praise'})
MATCH (t:Tone {value: 'enthusiastic_tone'})
MERGE (sit)-[:HAS_TONE]->(t);

MATCH (sit:Situation {situationId: 'painting_feedback_genuine_praise'})
MATCH (e:Expression {value: 'awe'})
MERGE (sit)-[:HAS_EXPRESSION]->(e);

MATCH (sit:Situation {situationId: 'painting_feedback_genuine_praise'})
MATCH (ctx:Context {value: 'They are looking at my painting'})
MERGE (sit)-[:HAS_CONTEXT]->(ctx);

MATCH (henry:Person {name: 'Henry'})
MATCH (stmt_b:Statement {statementId: 'stmt_great'})
MERGE (henry)-[:SAID]->(stmt_b);

MATCH (henry:Person {name: 'Henry'})
MATCH (e:Expression {value: 'awe'})
MERGE (henry)-[:HAS_EXPRESSION]->(e);

MATCH (stmt_b:Statement {statementId: 'stmt_great'})
MATCH (lm:LiteralMeaning {value: 'praise'})
MERGE (stmt_b)-[:HAS_LITERAL_MEANING]->(lm);

MATCH (stmt_b:Statement {statementId: 'stmt_great'})
MATCH (t:Tone {value: 'enthusiastic_tone'})
MERGE (stmt_b)-[:HAS_TONE]->(t);

// ---- Signal edges — Situation B ----

MATCH (sit:Situation {situationId: 'painting_feedback_genuine_praise'})
MATCH (ss:SituationSignal {situationSignalId: 'sig_b_literal'})
MERGE (sit)-[:HAS_SIGNAL]->(ss);

MATCH (sit:Situation {situationId: 'painting_feedback_genuine_praise'})
MATCH (ss:SituationSignal {situationSignalId: 'sig_b_expression'})
MERGE (sit)-[:HAS_SIGNAL]->(ss);

MATCH (sit:Situation {situationId: 'painting_feedback_genuine_praise'})
MATCH (ss:SituationSignal {situationSignalId: 'sig_b_tone'})
MERGE (sit)-[:HAS_SIGNAL]->(ss);

MATCH (sit:Situation {situationId: 'painting_feedback_genuine_praise'})
MATCH (ss:SituationSignal {situationSignalId: 'sig_b_context'})
MERGE (sit)-[:HAS_SIGNAL]->(ss);

MATCH (ss:SituationSignal {situationSignalId: 'sig_b_literal'})
MATCH (st:SignalType {signalTypeId: 'st_lm_praise'})
MERGE (ss)-[:INSTANCE_OF]->(st);

MATCH (ss:SituationSignal {situationSignalId: 'sig_b_expression'})
MATCH (st:SignalType {signalTypeId: 'st_expr_awe'})
MERGE (ss)-[:INSTANCE_OF]->(st);

MATCH (ss:SituationSignal {situationSignalId: 'sig_b_tone'})
MATCH (st:SignalType {signalTypeId: 'st_tone_enthusiastic'})
MERGE (ss)-[:INSTANCE_OF]->(st);

MATCH (ss:SituationSignal {situationSignalId: 'sig_b_context'})
MATCH (st:SignalType {signalTypeId: 'st_ctx_painting'})
MERGE (ss)-[:INSTANCE_OF]->(st);
