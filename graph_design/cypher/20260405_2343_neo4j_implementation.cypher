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
FOR (sit:Situation) REQUIRE sit.situationId IS UNIQUE;

CREATE CONSTRAINT signal_type_id_unique IF NOT EXISTS
FOR (st:SignalType) REQUIRE st.signalTypeId IS UNIQUE;

CREATE CONSTRAINT situation_signal_id_unique IF NOT EXISTS
FOR (ss:SituationSignal) REQUIRE ss.situationSignalId IS UNIQUE;

CREATE CONSTRAINT pattern_id_unique IF NOT EXISTS
FOR (pat:Pattern) REQUIRE pat.patternId IS UNIQUE;

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
      im.description = 'The speaker intends the opposite of the literal meaning, implying criticism';

MERGE (im:IntendedMeaning {value: 'indifference'})
  SET im.name = 'Indifference',
      im.description = 'The speaker is not genuinely engaged or invested';

MERGE (im:IntendedMeaning {value: 'compliment'})
  SET im.name = 'Compliment',
      im.description = 'The speaker is offering a polite positive remark';

MERGE (im:IntendedMeaning {value: 'praise'})
  SET im.name = 'Genuine Praise',
      im.description = 'The speaker is sincerely and enthusiastically praising the subject';

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

MERGE (pat:Pattern {patternId: 'pattern_sarcasm'})
  SET pat.name = 'Sarcasm Pattern',
      pat.description = 'Praise given with a dry tone and eye roll in a painting context suggests sarcasm',
      pat.match_mode = 'all_required',
      pat.min_coverage = 1.0;

MERGE (pat:Pattern {patternId: 'pattern_genuine_praise'})
  SET pat.name = 'Genuine Praise Pattern',
      pat.description = 'Praise given with an enthusiastic tone and awe expression in a painting context suggests genuine admiration',
      pat.match_mode = 'all_required',
      pat.min_coverage = 1.0;

// ============================================================
// PATTERN → REQUIRES → SignalType  (Sarcasm Pattern)
// ============================================================

MATCH (pat:Pattern {patternId: 'pattern_sarcasm'})
MATCH (st:SignalType {signalTypeId: 'st_lm_praise'})
MERGE (pat)-[:REQUIRES {weight: 1.0}]->(st);

MATCH (pat:Pattern {patternId: 'pattern_sarcasm'})
MATCH (st:SignalType {signalTypeId: 'st_expr_eye_roll'})
MERGE (pat)-[:REQUIRES {weight: 1.0}]->(st);

MATCH (pat:Pattern {patternId: 'pattern_sarcasm'})
MATCH (st:SignalType {signalTypeId: 'st_tone_dry'})
MERGE (pat)-[:REQUIRES {weight: 1.0}]->(st);

MATCH (pat:Pattern {patternId: 'pattern_sarcasm'})
MATCH (st:SignalType {signalTypeId: 'st_ctx_painting'})
MERGE (pat)-[:REQUIRES {weight: 1.0}]->(st);

// ============================================================
// PATTERN → PREDICTS → IntendedMeaning  (Sarcasm Pattern)
// ============================================================

MATCH (pat:Pattern {patternId: 'pattern_sarcasm'})
MATCH (im:IntendedMeaning {value: 'sarcasm'})
MERGE (pat)-[:PREDICTS {probability: 0.8}]->(im);

// ============================================================
// PATTERN → REQUIRES → SignalType  (Genuine Praise Pattern)
// ============================================================

MATCH (pat:Pattern {patternId: 'pattern_genuine_praise'})
MATCH (st:SignalType {signalTypeId: 'st_lm_praise'})
MERGE (pat)-[:REQUIRES {weight: 1.0}]->(st);

MATCH (pat:Pattern {patternId: 'pattern_genuine_praise'})
MATCH (st:SignalType {signalTypeId: 'st_expr_awe'})
MERGE (pat)-[:REQUIRES {weight: 1.0}]->(st);

MATCH (pat:Pattern {patternId: 'pattern_genuine_praise'})
MATCH (st:SignalType {signalTypeId: 'st_tone_enthusiastic'})
MERGE (pat)-[:REQUIRES {weight: 1.0}]->(st);

MATCH (pat:Pattern {patternId: 'pattern_genuine_praise'})
MATCH (st:SignalType {signalTypeId: 'st_ctx_painting'})
MERGE (pat)-[:REQUIRES {weight: 1.0}]->(st);

// ============================================================
// PATTERN → PREDICTS → IntendedMeaning  (Genuine Praise Pattern)
// ============================================================

MATCH (pat:Pattern {patternId: 'pattern_genuine_praise'})
MATCH (im:IntendedMeaning {value: 'praise'})
MERGE (pat)-[:PREDICTS {probability: 0.85}]->(im);

// ============================================================
// SITUATION A — Sarcasm
// ============================================================

// Person
MERGE (alice:Person {name: 'Alice'})
  SET alice.description = 'Speaker in the sarcasm situation';

// Statement
MERGE (stmt_a:Statement {statementId: 'stmt_congrats'})
  SET stmt_a.text = 'Congratulations, it\'s definitely original',
      stmt_a.name = 'Dry Congratulations';

// Situation node
MERGE (sit_a:Situation {situationId: 'painting_feedback_sarcasm'})
  SET sit_a.name = 'Painting Feedback — Sarcasm',
      sit_a.description = 'Alice looks at my painting and says \'Congratulations, it\'s definitely original\' in a dry tone with an eye-roll expression.';

// SituationSignal nodes for Situation A
MERGE (ss_a_lit:SituationSignal {situationSignalId: 'sig_a_literal'})
  SET ss_a_lit.situationId = 'painting_feedback_sarcasm',
      ss_a_lit.kind = 'literal_meaning',
      ss_a_lit.valueId = 'praise',
      ss_a_lit.name = 'Situation A — Literal Meaning Signal';

MERGE (ss_a_expr:SituationSignal {situationSignalId: 'sig_a_expression'})
  SET ss_a_expr.situationId = 'painting_feedback_sarcasm',
      ss_a_expr.kind = 'expression',
      ss_a_expr.valueId = 'eye_roll',
      ss_a_expr.name = 'Situation A — Expression Signal';

MERGE (ss_a_tone:SituationSignal {situationSignalId: 'sig_a_tone'})
  SET ss_a_tone.situationId = 'painting_feedback_sarcasm',
      ss_a_tone.kind = 'tone',
      ss_a_tone.valueId = 'dry_tone',
      ss_a_tone.name = 'Situation A — Tone Signal';

MERGE (ss_a_ctx:SituationSignal {situationSignalId: 'sig_a_context'})
  SET ss_a_ctx.situationId = 'painting_feedback_sarcasm',
      ss_a_ctx.kind = 'context',
      ss_a_ctx.valueId = 'They are looking at my painting',
      ss_a_ctx.name = 'Situation A — Context Signal';

// ============================================================
// SITUATION A — Observational edges (literal channel)
// ============================================================

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

MATCH (sit_a:Situation {situationId: 'painting_feedback_sarcasm'})
MATCH (alice:Person {name: 'Alice'})
MERGE (sit_a)-[:HAS_SPEAKER]->(alice);

MATCH (sit_a:Situation {situationId: 'painting_feedback_sarcasm'})
MATCH (stmt_a:Statement {statementId: 'stmt_congrats'})
MERGE (sit_a)-[:HAS_STATEMENT]->(stmt_a);

MATCH (sit_a:Situation {situationId: 'painting_feedback_sarcasm'})
MATCH (t:Tone {value: 'dry_tone'})
MERGE (sit_a)-[:HAS_TONE]->(t);

MATCH (sit_a:Situation {situationId: 'painting_feedback_sarcasm'})
MATCH (e:Expression {value: 'eye_roll'})
MERGE (sit_a)-[:HAS_EXPRESSION]->(e);

MATCH (sit_a:Situation {situationId: 'painting_feedback_sarcasm'})
MATCH (ctx:Context {value: 'They are looking at my painting'})
MERGE (sit_a)-[:HAS_CONTEXT]->(ctx);

// ============================================================
// SITUATION A — Inference channel edges
// ============================================================

MATCH (sit_a:Situation {situationId: 'painting_feedback_sarcasm'})
MATCH (ss:SituationSignal {situationSignalId: 'sig_a_literal'})
MERGE (sit_a)-[:HAS_SIGNAL]->(ss);

MATCH (sit_a:Situation {situationId: 'painting_feedback_sarcasm'})
MATCH (ss:SituationSignal {situationSignalId: 'sig_a_expression'})
MERGE (sit_a)-[:HAS_SIGNAL]->(ss);

MATCH (sit_a:Situation {situationId: 'painting_feedback_sarcasm'})
MATCH (ss:SituationSignal {situationSignalId: 'sig_a_tone'})
MERGE (sit_a)-[:HAS_SIGNAL]->(ss);

MATCH (sit_a:Situation {situationId: 'painting_feedback_sarcasm'})
MATCH (ss:SituationSignal {situationSignalId: 'sig_a_context'})
MERGE (sit_a)-[:HAS_SIGNAL]->(ss);

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

// Person
MERGE (henry:Person {name: 'Henry'})
  SET henry.description = 'Speaker in the genuine praise situation';

// Statement
MERGE (stmt_b:Statement {statementId: 'stmt_great'})
  SET stmt_b.text = 'It\'s great, it\'s very original',
      stmt_b.name = 'Enthusiastic Praise';

// Situation node
MERGE (sit_b:Situation {situationId: 'painting_feedback_genuine_praise'})
  SET sit_b.name = 'Painting Feedback — Genuine Praise',
      sit_b.description = 'Henry looks at my painting and says \'It\'s great, it\'s very original\' in an enthusiastic tone with an expression of awe.';

// SituationSignal nodes for Situation B
MERGE (ss_b_lit:SituationSignal {situationSignalId: 'sig_b_literal'})
  SET ss_b_lit.situationId = 'painting_feedback_genuine_praise',
      ss_b_lit.kind = 'literal_meaning',
      ss_b_lit.valueId = 'praise',
      ss_b_lit.name = 'Situation B — Literal Meaning Signal';

MERGE (ss_b_expr:SituationSignal {situationSignalId: 'sig_b_expression'})
  SET ss_b_expr.situationId = 'painting_feedback_genuine_praise',
      ss_b_expr.kind = 'expression',
      ss_b_expr.valueId = 'awe',
      ss_b_expr.name = 'Situation B — Expression Signal';

MERGE (ss_b_tone:SituationSignal {situationSignalId: 'sig_b_tone'})
  SET ss_b_tone.situationId = 'painting_feedback_genuine_praise',
      ss_b_tone.kind = 'tone',
      ss_b_tone.valueId = 'enthusiastic_tone',
      ss_b_tone.name = 'Situation B — Tone Signal';

MERGE (ss_b_ctx:SituationSignal {situationSignalId: 'sig_b_context'})
  SET ss_b_ctx.situationId = 'painting_feedback_genuine_praise',
      ss_b_ctx.kind = 'context',
      ss_b_ctx.valueId = 'They are looking at my painting',
      ss_b_ctx.name = 'Situation B — Context Signal';

// ============================================================
// SITUATION B — Observational edges (literal channel)
// ============================================================

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

MATCH (sit_b:Situation {situationId: 'painting_feedback_genuine_praise'})
MATCH (henry:Person {name: 'Henry'})
MERGE (sit_b)-[:HAS_SPEAKER]->(henry);

MATCH (sit_b:Situation {situationId: 'painting_feedback_genuine_praise'})
MATCH (stmt_b:Statement {statementId: 'stmt_great'})
MERGE (sit_b)-[:HAS_STATEMENT]->(stmt_b);

MATCH (sit_b:Situation {situationId: 'painting_feedback_genuine_praise'})
MATCH (t:Tone {value: 'enthusiastic_tone'})
MERGE (sit_b)-[:HAS_TONE]->(t);

MATCH (sit_b:Situation {situationId: 'painting_feedback_genuine_praise'})
MATCH (e:Expression {value: 'awe'})
MERGE (sit_b)-[:HAS_EXPRESSION]->(e);

MATCH (sit_b:Situation {situationId: 'painting_feedback_genuine_praise'})
MATCH (ctx:Context {value: 'They are looking at my painting'})
MERGE (sit_b)-[:HAS_CONTEXT]->(ctx);

// ============================================================
// SITUATION B — Inference channel edges
// ============================================================

MATCH (sit_b:Situation {situationId: 'painting_feedback_genuine_praise'})
MATCH (ss:SituationSignal {situationSignalId: 'sig_b_literal'})
MERGE (sit_b)-[:HAS_SIGNAL]->(ss);

MATCH (sit_b:Situation {situationId: 'painting_feedback_genuine_praise'})
MATCH (ss:SituationSignal {situationSignalId: 'sig_b_expression'})
MERGE (sit_b)-[:HAS_SIGNAL]->(ss);

MATCH (sit_b:Situation {situationId: 'painting_feedback_genuine_praise'})
MATCH (ss:SituationSignal {situationSignalId: 'sig_b_tone'})
MERGE (sit_b)-[:HAS_SIGNAL]->(ss);

MATCH (sit_b:Situation {situationId: 'painting_feedback_genuine_praise'})
MATCH (ss:SituationSignal {situationSignalId: 'sig_b_context'})
MERGE (sit_b)-[:HAS_SIGNAL]->(ss);

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
