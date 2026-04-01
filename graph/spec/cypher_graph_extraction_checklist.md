# Step-by-step checklist: Cypher file -> Neo4j -> `cytoscape_elements.json` -> `index.html`

Use this document when you already have:
- `graph/cypher/*_neo4j_implementation.cypher` (pick one that matches your schema/data)
- `graph/pipeline/export_graph_to_cytoscape.py`
- `index.html`

Goal:
1. Load the `.cypher` file into Neo4j Desktop
2. Export graph data to `cytoscape_elements.json`
3. Visualize it in the browser with `index.html`

---

## 0) Open project terminal in the correct folder

In PowerShell:

```powershell
cd "C:\Users\RobertTomasJohnston\OneDrive\Documents\Coding\Projects\social_situations_graph"
```

Confirm the required files exist:

```powershell
ls "graph\pipeline\export_graph_to_cytoscape.py","graph\cypher\*_neo4j_implementation.cypher","index.html"
```

---

## 1) Start Neo4j Desktop and verify connectivity

1. Open Neo4j Desktop and start your DBMS (status must be **Running**).
2. Confirm Bolt connection is reachable:

```powershell
Test-NetConnection 127.0.0.1 -Port 7687
```

Pass condition:
- `TcpTestSucceeded : True`

If it is `False`, do not continue yet. Fix DBMS startup/port first.

---

## 2) Load `20260327_1446_neo4j_implementation.cypher` into Neo4j

### 2A) Find your `cypher-shell.bat` path (Neo4j Desktop on Windows)

`cypher-shell` is usually not on PATH. Use the DBMS-local `.bat` file from your Neo4j Desktop DBMS folder.

Typical location pattern:
- `C:\Users\RobertTomasJohnston\.Neo4jDesktop2\Data\dbmss\<your-dbms-id>\bin\cypher-shell.bat`

### 2B) Run the load command

Use this template:

```powershell
& "C:\Users\RobertTomasJohnston\.Neo4jDesktop2\Data\dbmss\dbms-ee9797b2-9ef1-48ce-90c9-4712513ceb04\bin\cypher-shell.bat" `
  -a "neo4j://localhost:7687" `
  -u "neo4j" `
  -p "granxols5" `
  -d "autistgraph" `
  -f "C:\Users\RobertTomasJohnston\OneDrive\Documents\Coding\Projects\social_situations_graph\graph\cypher\20260327_1446_neo4j_implementation.cypher"
```

Pass condition:
- Command finishes without Cypher errors.

If you get `"java" is not recognized`, install Java or restart Cursor/terminal so Java is available.

---

## 3) Validate that data was loaded (important)

In Neo4j Browser, run:

```cypher
MATCH (n) RETURN count(n) AS nodes;
MATCH ()-[r]->() RETURN count(r) AS rels;
```

Pass conditions:
- `nodes > 0`
- `rels > 0`

If `rels = 0`, export will be empty because the exporter uses:
- `MATCH (n)-[r]->(m) RETURN n, r, m`

---

## 4) Export from Neo4j to `cytoscape_elements.json`

### 4A) Ensure Python dependency is installed

```powershell
pip install neo4j
```

### 4B) (Optional but recommended) verify `.env` values

`export_graph_to_cytoscape.py` supports:
- `NEO4J_URI`, `NEO4J_USER`, `NEO4J_PASSWORD`, `NEO4J_DATABASE`
- or fallback keys: `neo4j_username`, `neo4j_password`

### 4C) Run export

```powershell
python "graph\pipeline\export_graph_to_cytoscape.py"
```

Pass condition:
- Terminal prints `Wrote X nodes and Y edges`
- File `graph/exports/cytoscape_elements.json` is created

Quick check:

```powershell
ls "graph\exports\cytoscape_elements.json"
```

---

## 5) Visualize with `index.html`

Do not open `index.html` directly as a file path because it fetches JSON. Serve the folder:

```powershell
python -m http.server 8000
```

Then open:
- [http://localhost:8000/index.html](http://localhost:8000/index.html)

Pass condition:
- Graph renders on screen (nodes + edges visible)

---

## 6) Fast repeat workflow (after changing the Cypher file)

1. Re-run step 2 (`cypher-shell ... -f 20260327_1446_neo4j_implementation.cypher`)
2. Re-run step 4 (`python graph\pipeline\export_graph_to_cytoscape.py`)
3. Refresh browser tab at `http://localhost:8000/index.html`

---

## 7) Troubleshooting quick map

- `TcpTestSucceeded : False`
  - Neo4j DBMS is not running or wrong port.
- `Unauthorized` / auth failure during export
  - Wrong Neo4j username/password or mismatched `.env` values.
- Export succeeds but graph is empty
  - Check step 3 (`rels` likely 0).
- Browser shows fetch/load error
  - You opened file directly instead of using `python -m http.server 8000`.

---

## Annex A) How `autistgraph` database was created

Why this was needed:
- Running `cypher-shell` with `-d "neo4j"` failed with:
  - `22N51: graph reference not found`
- `SHOW DATABASES` showed only `system`, so there was no user database yet.

### A1) Check existing databases (from `system`)

```powershell
& "C:\Users\RobertTomasJohnston\.Neo4jDesktop2\Data\dbmss\dbms-ee9797b2-9ef1-48ce-90c9-4712513ceb04\bin\cypher-shell.bat" `
  -a "neo4j://localhost:7687" `
  -u "neo4j" `
  -p "granxols5" `
  -d "system" `
  "SHOW DATABASES;"
```

### A2) Create the user database

```powershell
& "C:\Users\RobertTomasJohnston\.Neo4jDesktop2\Data\dbmss\dbms-ee9797b2-9ef1-48ce-90c9-4712513ceb04\bin\cypher-shell.bat" `
  -a "neo4j://localhost:7687" `
  -u "neo4j" `
  -p "granxols5" `
  -d "system" `
  "CREATE DATABASE autistgraph IF NOT EXISTS;"
```

### A3) Verify creation

```powershell
& "C:\Users\RobertTomasJohnston\.Neo4jDesktop2\Data\dbmss\dbms-ee9797b2-9ef1-48ce-90c9-4712513ceb04\bin\cypher-shell.bat" `
  -a "neo4j://localhost:7687" `
  -u "neo4j" `
  -p "granxols5" `
  -d "system" `
  "SHOW DATABASES;"
```

Expected result:
- `autistgraph` appears with `currentStatus = online`

### A4) Use `autistgraph` in both load and export

- In load command: set `-d "autistgraph"`
- In `.env`: set `NEO4J_DATABASE=autistgraph`

