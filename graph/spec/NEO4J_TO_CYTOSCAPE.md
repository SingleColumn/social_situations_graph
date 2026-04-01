# Workflow: Load Neo4j → Export JSON → Visualize (Cytoscape.js)

This repo has:

- `[timestamp]_neo4j_implementation.cypher`: creates constraints + loads sample data into Neo4j
- `graph/pipeline/export_graph_to_cytoscape.py`: exports the graph from Neo4j into Cytoscape.js-compatible JSON
- `index.html`: a simple Cytoscape.js viewer that loads `cytoscape_elements.json`

The recommended workflow is:

1) **Load / update Neo4j** from `[timestamp]_neo4j_implementation.cypher` (repeatable)
2) **Export** the graph to `cytoscape_elements.json`
3) **Serve** the folder and open the viewer

## Prerequisites

- Neo4j running locally (Bolt enabled)
  - Neo4j Browser usually at `http://localhost:7474`
    <!--
    Opening the Neo4j Browser is helpful because it allows you to visually inspect your database, run Cypher queries manually, and verify that your data was loaded correctly. However, you do NOT need to keep the browser open for cypher-shell or scripts to connect; it's just a web client for convenience.
    -->
  - Bolt is Neo4j’s native network protocol for client applications and tools (like cypher-shell and Python scripts) to connect and execute queries.
    - Bolt is usually available at `neo4j://localhost:7687` or `bolt://localhost:7687`.
    - <!--
      Even if you have Neo4j Browser open, Bolt must also be enabled and accessible because it is what programmatic tools use to connect. The browser and Bolt can be used independently; opening the browser does not "open" or "close" the Bolt port. Both are typically enabled by default in a local install.
      -->
- `cypher-shell` available
  - Included with Neo4j Desktop / Neo4j Server installs
- Python installed (3.10+ recommended)

## 1) Load the graph into Neo4j (from file)

### Neo4j Desktop note (Windows)

If you see an error like `cypher-shell : El término 'cypher-shell' no se reconoce...`, it means `cypher-shell` isn’t on your PATH. Neo4j Desktop includes it as a `.bat` inside the DBMS install folder. Run it by full path using PowerShell’s call operator (`&`):

```powershell

& "C:\Users\RobertTomasJohnston\.Neo4jDesktop2\Data\dbmss\dbms-ee9797b2-9ef1-48ce-90c9-4712513ceb04\bin\cypher-shell.bat" `
  -a "neo4j://localhost:7687" `
  -u "neo4j" `
  -p "granxols5" `
  -d "neo4j" `
  -f "C:\Users\RobertTomasJohnston\OneDrive\Documents\Coding\Projects\social_situations_graph\graph\cypher\20260327_1446_neo4j_implementation.cypher"
```

Notes:

- `-a`: Neo4j Bolt/Neo4j URI
- `-u` / `-p`: Neo4j credentials
- `-d`: database name (omit if you’re using the default and your Neo4j version doesn’t need it)
- `-f`: path to the `.cypher` file to execute

If this succeeds, your DB should contain nodes + relationships. You can verify in Neo4j Browser:

```cypher
MATCH (n) RETURN count(n);
```

## 2) Export Cytoscape JSON

Install the driver once:

```bash
pip install neo4j
```

Run the exporter:

```bash
python graph/pipeline/export_graph_to_cytoscape.py
```

Output:

- `graph/exports/cytoscape_elements.json` (fetched by `index.html`)

If authentication fails, the exporter will prompt you for a username/password.

### Optional: configure via `.env`

The exporter supports either `NEO4J_*` variables or the shorter keys you already use.

Recommended `.env` format:

```env
NEO4J_URI=neo4j://localhost:7687
NEO4J_USER=neo4j
NEO4J_PASSWORD=YOUR_PASSWORD
NEO4J_DATABASE=neo4j
```

## 3) Visualize with `index.html`

Because the viewer uses `fetch()` to load `cytoscape_elements.json`, you should serve the folder with a local web server (opening the HTML file directly may be blocked by browser CORS/file rules).

From the project directory:

```bash
python -m http.server 8000
```

Then open:

- `http://localhost:8000/index.html`

## Quick repeat loop

When you change `neo4j_implementation.cypher`:

1. Re-run the `cypher-shell ... -f neo4j_implementation.cypher` command
2. Re-run `python graph/pipeline/export_graph_to_cytoscape.py`
3. Refresh the browser tab

