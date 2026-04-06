# Graph implementation: pipeline, verification, and troubleshooting

This document covers running the pipeline, verifying it completed correctly, and recovering from failures.

---

## How the pipeline works

```powershell
.\graph_design\pipeline\run_graph_pipeline.ps1
```

1. **Generate Cypher** — calls Claude with `graph_design/spec/graph_specification.md` and writes a timestamped `.cypher` file to `graph_design/cypher/`.
2. **Reset and load Neo4j** — runs `MATCH (n) DETACH DELETE n` to wipe the database, then loads the generated Cypher.
3. **Export snapshot** — writes `graph_design/exports/cytoscape_elements.json` as a reference artifact.

The app reads directly from Neo4j at runtime, not from the snapshot.

---

## Prerequisites

- **Neo4j Desktop** running with a DBMS started (Bolt enabled, default port 7687).
- **Python** 3.10+ with the project `.venv` active, or `python` on PATH with `neo4j` and `anthropic` packages installed.
- **`.env`** at the project root:

```env
ANTHROPIC_API_KEY=...
NEO4J_URI=neo4j://localhost:7687
NEO4J_USER=neo4j
NEO4J_PASSWORD=...
NEO4J_DATABASE=neo4j
```

---

## Verification checklist

Run this after the pipeline to confirm each stage completed.

### 1 — Neo4j is reachable

```powershell
Test-NetConnection 127.0.0.1 -Port 7687
```

Pass: `TcpTestSucceeded : True`. If `False`, start the DBMS in Neo4j Desktop.

### 2 — Output files were written

```powershell
ls graph_design\cypher\*_neo4j_implementation.cypher | Sort-Object LastWriteTime -Descending | Select-Object -First 1
ls graph_design\cypher\*_NEO4J_SCHEMA.md             | Sort-Object LastWriteTime -Descending | Select-Object -First 1
```

Pass: at least one file of each type with today's timestamp.

### 3 — Data was loaded into Neo4j

In Neo4j Browser (`http://localhost:7474`):

```cypher
MATCH (n) RETURN count(n) AS nodes;
MATCH ()-[r]->() RETURN count(r) AS rels;
```

Pass: both greater than zero.

```cypher
MATCH (n) RETURN labels(n) AS label, count(n) AS count ORDER BY label;
```

Expected labels: `Context`, `Expression`, `IntendedMeaning`, `LiteralMeaning`, `Pattern`, `Person`, `SignalType`, `Situation`, `SituationSignal`, `Statement`, `Tone`.

### 4 — Patterns are connected to IntendedMeaning

```cypher
MATCH (p:Pattern)-[pred:PREDICTS]->(im:IntendedMeaning)
RETURN p.patternId, pred.probability, im.value;
```

Pass: at least two rows (one per pattern).

### 5 — SituationSignal → INSTANCE_OF → SignalType chain is intact

```cypher
MATCH (sit:Situation)-[:HAS_SIGNAL]->(ss:SituationSignal)-[:INSTANCE_OF]->(st:SignalType)
RETURN sit.situationId, ss.situationSignalId, st.kind, st.valueId
ORDER BY sit.situationId, st.kind;
```

Pass: 4 rows per situation (tone, expression, context, literal_meaning).

### 6 — App is serving the graph

```bash
npm run dev
```

Open `http://localhost:3000` and confirm:
- Graph nodes are visible
- Situation filter shows both situations
- Selecting a situation isolates its subgraph
- At least one Pattern node activates and an IntendedMeaning node is visible

---

## Manual steps (if pipeline fails)

### Load a Cypher file manually

```powershell
.venv\Scripts\python.exe graph_design\pipeline\load_cypher_into_neo4j.py `
  --input "graph_design\cypher\<timestamp>_neo4j_implementation.cypher" `
  --uri "neo4j://localhost:7687" `
  --user "neo4j" `
  --password "YOUR_PASSWORD" `
  --database "neo4j"
```

### Load via cypher-shell

`cypher-shell` ships with Neo4j Desktop but is typically not on PATH:

```
C:\Users\<you>\.Neo4jDesktop2\Data\dbmss\<dbms-id>\bin\cypher-shell.bat
```

```powershell
& "C:\path\to\cypher-shell.bat" `
  -a "neo4j://localhost:7687" `
  -u "neo4j" -p "YOUR_PASSWORD" -d "neo4j" `
  -f "graph_design\cypher\<timestamp>_neo4j_implementation.cypher"
```

### Export snapshot manually

```powershell
.venv\Scripts\python.exe graph_design\pipeline\export_graph_to_cytoscape.py
```

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `TcpTestSucceeded : False` on port 7687 | Neo4j DBMS not running or Bolt disabled |
| No `.cypher` file generated | Claude API key missing or invalid in `.env` |
| `Unauthorized` during load or export | Wrong password in `.env` |
| `ConstraintAlreadyExists` in loader output | Expected — loader skips safely |
| `nodes = 0` after pipeline | Load step failed; check pipeline output for errors |
| `rels = 0` but `nodes > 0` | MATCH+MATCH+MERGE statements failed; inspect the generated `.cypher` file |
| Export writes 0 nodes / 0 edges | Load step failed; run `MATCH (n) RETURN count(n)` in Neo4j Browser |
| IntendedMeaning nodes missing in app | PREDICTS edges not created; run check in step 4 above |
| Pattern not activating in app | INSTANCE_OF chain broken; run check in step 5 above |
| App graph is empty | Neo4j has no data, or app not connected to the right database |
