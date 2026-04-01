# export_autist_graph_to_cytoscape.py
#
# Purpose:
#   This script
# - connects to a Neo4j database (local or remote, as configured by the NEO4J_URI environment variable or .env file)
# - and exports the full graph (nodes and relationships) into a Cytoscape.js-compatible JSON file, suitable for visualization.
#
# Input:
#   - Reads all nodes and relationships from the Neo4j graph, using connection details
#     configured via environment variables or a local .env file (see README/NEO4J_TO_CYTOSCAPE.md).
#
# This script presupposes that the Neo4j database instance already contains the expected graph schema and data.
# In other words, the required .cypher file(s) (e.g., 20260323_1407_neo4j_implementation.cypher) must have been successfully LOADED into Neo4j Desktop (or the target Neo4j server) before you run this exporter.
# The script does NOT generate or load the cypher file itself; it only exports what presently exists in the connected Neo4j database.
# This includes creation of nodes and relationships for all needed types (e.g., Person, Statement, Tone, Context,
# LiteralMeaning, IntendedMeaning, Pattern, Situation, Signal, etc.)
# along with the correct constraints and indexes. The script assumes these have been loaded and exist prior to export.
#
# Output:
#   - Generates "cytoscape_elements.json" (overridable via OUTPUT_FILE env/key), which
#     can be loaded by the bundled index.html for interactive graph visualization.
#
#   Typical environment variables (or keys in .env):
#     NEO4J_URI, NEO4J_USER, NEO4J_PASSWORD, NEO4J_DATABASE, OUTPUT_FILE
#
import json
import os
import getpass
from neo4j import GraphDatabase
from neo4j.exceptions import AuthError, ClientError, ServiceUnavailable

def load_dotenv(path: str = ".env") -> dict:
    """
    Minimal .env loader (KEY=VALUE lines). Environment variables take precedence.
    """
    values: dict[str, str] = {}
    try:
        with open(path, "r", encoding="utf-8") as f:
            for raw_line in f:
                line = raw_line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                k = k.strip()
                v = v.strip().strip('"').strip("'")
                if k:
                    values[k] = v
    except FileNotFoundError:
        pass
    return values


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
# The pipeline scripts live under `graph/pipeline/`, but `.env` is at repo root.
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
ENV_FILE = load_dotenv(os.path.join(PROJECT_ROOT, ".env"))


def env_get(key: str, default: str | None = None) -> str | None:
    return os.environ.get(key) or ENV_FILE.get(key) or default


# ---- CONFIGURE VIA ENV OR DEFAULTS ----
# Supports either NEO4J_USER/NEO4J_PASSWORD or your existing neo4j_username/neo4j_password keys.
NEO4J_URI = env_get("NEO4J_URI", "bolt://localhost:7687")
NEO4J_USER = env_get("NEO4J_USER", env_get("neo4j_username", "neo4j"))
NEO4J_PASSWORD = env_get("NEO4J_PASSWORD", env_get("neo4j_password", ""))
NEO4J_DATABASE = env_get("NEO4J_DATABASE", None)  # e.g. "neo4j" or your DB name

# Default output goes to the legacy-friendly folder we created for exports.
OUTPUT_FILE = env_get(
    "OUTPUT_FILE", os.path.join(PROJECT_ROOT, "graph", "exports", "cytoscape_elements.json")
)
# --------------------------------------


# This section defines the Cypher query used to extract all relationships from the Neo4j database.
# It matches all node pairs connected by a relationship, returning each source node (n),
# the relationship (r), and the target node (m). The resulting data forms the basis for
# building the Cytoscape.js graph structure exported by this script.
CYPHER_QUERY = """
// Export all relationships in the "Simple Autistic Social Interpretation Graph"
MATCH (n)-[r]->(m)
RETURN n, r, m
"""


def node_to_dict(node, cy_id: str):
    """
    Convert a neo4j.Node to a JSON-serializable dict.
    - id: internal Neo4j id (string)
    - label: first label (Person, Statement, Tone, ...)
    - includes all node properties (id, text, description, etc.)
    """
    element_id = getattr(node, "element_id", None)
    if element_id is None or str(element_id).strip() == "":
        element_id = str(getattr(node, "id", ""))

    data = {"id": cy_id, "neo4jElementId": str(element_id)}

    labels = list(node.labels)
    if labels:
        data["label"] = labels[0]

    for k, v in node.items():
        # avoid clobbering Cytoscape's required `id`
        if k == "id":
            data["neo4jId"] = v
        else:
            data[k] = v

    return data


def relationship_to_dict(rel, source_cy_id: str, target_cy_id: str):
    """
    Convert a neo4j.Relationship to a JSON-serializable dict.
    - source/target: node ids (string)
    - type: relationship type (SAID, HAS_TONE, SUGGESTS, INCREASES_PROBABILITY_OF, ...)
    - includes all relationship properties (if you add any later)
    """
    data = {"source": source_cy_id, "target": target_cy_id, "type": rel.type}

    for k, v in rel.items():
        data[k] = v

    return data


def _best_node_key(node) -> str:
    """
    Use stable schema-level keys so distinct domain instances are not merged.
    This keeps visualization faithful to the PRD model.
    """
    props = dict(node.items())
    label = next(iter(node.labels), "Node")

    # Schema-specific identity keys first
    label_id_fields = {
        "Statement": ["instanceId"],
        "Situation": ["situationId"],
        "Person": ["name"],
        "Tone": ["value"],
        "Expression": ["value"],
        "Context": ["value"],
        "LiteralMeaning": ["value"],
        "IntendedMeaning": ["value"],
        "Pattern": ["patternId"],
        "Signal": ["signalId"],
    }

    for field in label_id_fields.get(label, []):
        val = props.get(field)
        if val is not None and str(val).strip() != "":
            return f"{label}:{val}"

    # Generic domain key fallback
    if "id" in props and props["id"] is not None and str(props["id"]).strip() != "":
        return f"{label}:{props['id']}"

    element_id = getattr(node, "element_id", None)
    if element_id is None or str(element_id).strip() == "":
        element_id = getattr(node, "id", "")
    return f"{label}:internal:{element_id}"


def export_for_cytoscape():
    user = NEO4J_USER or "neo4j"
    password = NEO4J_PASSWORD or ""

    def _make_driver(u: str, pw: str):
        return GraphDatabase.driver(NEO4J_URI, auth=(u, pw))

    # Try current creds first; if auth fails, prompt.
    driver = _make_driver(user, password)
    session_kwargs: dict[str, str] = {}
    if NEO4J_DATABASE:
        session_kwargs["database"] = NEO4J_DATABASE

    try:
        try:
            with driver.session(**session_kwargs) as session:
                session.run("RETURN 1").consume()
        except ClientError as e:
            if "databasenotfound" in str(e).lower() or "graph reference not found" in str(e).lower():
                print(f"Database '{NEO4J_DATABASE}' not found; retrying with the default database...")
                session_kwargs = {}
                with driver.session() as session:
                    session.run("RETURN 1").consume()
            else:
                raise
    except ServiceUnavailable as e:
        driver.close()
        raise SystemExit(f"Neo4j unavailable at {NEO4J_URI}. Is the DB running and Bolt enabled?\n{e}") from e
    except AuthError:
        driver.close()
        print(f"Authentication failed for user '{user}'.")
        user = input("Neo4j username: ").strip() or user
        password = getpass.getpass("Neo4j password: ")
        driver = _make_driver(user, password)
        # Validate prompted creds
        try:
            with driver.session(**session_kwargs) as session:
                session.run("RETURN 1").consume()
        except ClientError as e:
            if "databasenotfound" in str(e).lower() or "graph reference not found" in str(e).lower():
                print(f"Database '{NEO4J_DATABASE}' not found; retrying with the default database...")
                session_kwargs = {}
                with driver.session() as session:
                    session.run("RETURN 1").consume()
            else:
                raise

    try:
        with driver.session(**session_kwargs) as session:
            result = session.run(CYPHER_QUERY)

            nodes_by_cy_id = {}
            edges = []

            for record in result:
                n = record["n"]
                r = record["r"]
                m = record["m"]

                n_cy_id = _best_node_key(n)
                m_cy_id = _best_node_key(m)

                if n_cy_id not in nodes_by_cy_id:
                    nodes_by_cy_id[n_cy_id] = node_to_dict(n, n_cy_id)
                if m_cy_id not in nodes_by_cy_id:
                    nodes_by_cy_id[m_cy_id] = node_to_dict(m, m_cy_id)

                edges.append(relationship_to_dict(r, n_cy_id, m_cy_id))

            elements = []

            # Nodes
            for node in nodes_by_cy_id.values():
                elements.append({"data": node})

            # Edges (give each an id)
            for i, edge in enumerate(edges):
                elements.append({"data": {"id": f"e{i}", **edge}})

            graph_json = {"elements": elements}

            with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
                json.dump(graph_json, f, ensure_ascii=False, indent=2)

            print(f"Wrote {len(nodes_by_cy_id)} nodes and {len(edges)} edges")
            print(f"Output: {OUTPUT_FILE}")

    finally:
        driver.close()


if __name__ == "__main__":
    export_for_cytoscape()