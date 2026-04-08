import argparse
import json
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent
APP_WEB_DIR = PROJECT_ROOT / "app" / "web"


STATIC_APP_JS = r"""
function prettifyType(type) {
  if (!type) return "";
  return String(type).replace(/_/g, " ");
}

function setStatus(message) {
  const hint = document.getElementById("hint");
  if (hint && message) {
    hint.textContent = message;
  }
}

async function loadGraphData() {
  const embeddedGraphNode = document.getElementById("embedded-graph-data");
  const rawGraph = embeddedGraphNode?.textContent || "";

  if (rawGraph.trim()) {
    try {
      const embedded = JSON.parse(rawGraph);
      if (Array.isArray(embedded?.elements) && embedded.elements.length > 0) {
        return embedded;
      }
    } catch (error) {
      setStatus(`Embedded graph JSON failed to parse. Falling back to static JSON file. ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  const response = await fetch("./graph_design/exports/cytoscape_elements.json?v=" + Date.now(), { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`Static graph JSON request failed with HTTP ${response.status}.`);
  }
  return response.json();
}

function fallbackLabel(data) {
  if (!data) return "";
  if (data.neo4jId) return String(data.neo4jId);
  if (data.neo4jElementId) return String(data.neo4jElementId);
  if (data.id) return String(data.id).replace(/^[^:]+:/, "");
  return "node";
}

function humanizeSituationLabel(data) {
  const directDescription = [data?.description, data?.summary, data?.title]
    .map((value) => (typeof value === "string" ? value.trim() : ""))
    .find(Boolean);
  if (directDescription) return directDescription;

  const rawId = String(data?.situationId || fallbackLabel(data) || "");
  const withoutPrefix = rawId.replace(/^situation[_\-\s:]*/i, "");
  const normalized = withoutPrefix
    .replace(/[_-]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();

  if (!normalized) return "Situation";
  return `Situation: ${normalized.replace(/\b\w/g, (char) => char.toUpperCase())}`;
}

function computeNodeDisplayLabel(data) {
  const nodeType = data?.label;
  if (nodeType === "Person") return `Person: ${data.name || fallbackLabel(data)}`;
  if (nodeType === "Statement") return `Statement: ${data.text || data.instanceId || fallbackLabel(data)}`;
  if (nodeType === "Tone") return `Tone: ${data.value || fallbackLabel(data)}`;
  if (nodeType === "Expression") return `Expression: ${data.value || fallbackLabel(data)}`;
  if (nodeType === "Context") return `Context: ${data.value || fallbackLabel(data)}`;
  if (nodeType === "LiteralMeaning") return `Literal meaning: ${data.value || fallbackLabel(data)}`;
  if (nodeType === "IntendedMeaning") return `Intended meaning: ${data.value || fallbackLabel(data)}`;
  if (nodeType === "Pattern") return `Pattern: ${data.patternId || fallbackLabel(data)}`;
  if (nodeType === "SituationSignal") {
    const kind = data.kind || "signal";
    const valueId = data.valueId || fallbackLabel(data);
    return `Signal: ${kind} / ${valueId}`;
  }
  if (nodeType === "SignalType") {
    const kind = data.kind || "type";
    const valueId = data.valueId || fallbackLabel(data);
    return `SignalType: ${kind} / ${valueId}`;
  }
  if (nodeType === "Situation") return humanizeSituationLabel(data);
  return fallbackLabel(data);
}

function enrichElements(elements) {
  return (elements || []).map((el) => {
    if (!el?.data) return el;
    if (el.data.source && el.data.target) {
      const typeStr = prettifyType(el.data.type);
      const p = el.data.probability;
      const displayType = p !== undefined && p !== null && String(p) !== "" ? `${typeStr} (p=${p})` : typeStr;
      return { ...el, data: { ...el.data, displayType } };
    }
    return { ...el, data: { ...el.data, displayLabel: computeNodeDisplayLabel(el.data) } };
  });
}

function buildTypeLayeredPositions(elements) {
  const typeOrder = ["Situation", "Person", "Statement", "LiteralMeaning", "Tone", "Expression", "Context", "SituationSignal", "SignalType", "Pattern", "IntendedMeaning"];
  const typeToRow = Object.fromEntries(typeOrder.map((t, i) => [t, i]));
  const grouped = new Map();
  for (const el of elements) {
    const d = el?.data;
    if (!d || d.source || d.target) continue;
    const type = d.label || "Other";
    if (!grouped.has(type)) grouped.set(type, []);
    grouped.get(type).push(el);
  }
  for (const [, list] of grouped.entries()) {
    list.sort((a, b) => String(a.data?.displayLabel || a.data?.id || "").localeCompare(String(b.data?.displayLabel || b.data?.id || "")));
  }
  const positions = {};
  const colGap = 280;
  const rowGap = 260;
  const startX = 120;
  const startY = 120;
  const laneSplitAfterRow = 6;
  const laneGap = 220;
  for (const [type, list] of grouped.entries()) {
    const rowIndex = typeToRow[type] ?? typeOrder.length;
    const channelOffset = rowIndex > laneSplitAfterRow ? laneGap : 0;
    const rowY = startY + rowIndex * rowGap + channelOffset;
    list.forEach((nodeEl, idx) => {
      const colX = startX + idx * colGap;
      positions[nodeEl.data.id] = { x: colX, y: rowY };
    });
  }
  return positions;
}

function classifyChannel(edgeType) {
  const literalTypes = new Set(["SAID", "HAS_EXPRESSION", "HAS_TONE", "HAS_LITERAL_MEANING", "HAS_CONTEXT", "HAS_SPEAKER", "HAS_STATEMENT"]);
  const inferenceTypes = new Set(["HAS_SIGNAL", "INSTANCE_OF", "SUGGESTS", "DERIVED_AS"]);
  const patternTypes = new Set(["REQUIRES", "PREDICTS"]);
  if (literalTypes.has(edgeType)) return "literal";
  if (inferenceTypes.has(edgeType)) return "inference";
  if (patternTypes.has(edgeType)) return "pattern";
  return "other";
}

window.addEventListener("error", (event) => {
  const msg = event?.error?.message || event?.message || "Unknown JavaScript error.";
  setStatus(`Static page error: ${msg}`);
});

loadGraphData()
  .then((graph) => {
    if (!Array.isArray(graph?.elements) || graph.elements.length === 0) {
      setStatus("Graph snapshot is empty. Re-run the graph pipeline.");
      return;
    }

    const elements = enrichElements(graph.elements);
    const cy = cytoscape({
      container: document.getElementById("cy"),
      elements,
      minZoom: 0.35,
      maxZoom: 3.5,
      wheelSensitivity: 0.15,
      selectionType: "additive",
      boxSelectionEnabled: true,
      style: [
        { selector: "node", style: { "background-color": "#4f46e5", label: "data(displayLabel)", color: "#e5e7eb", "font-size": 16, "text-valign": "center", "text-halign": "center", "text-wrap": "wrap", "text-max-width": "300px", "text-background-color": "#0f172a", "text-background-opacity": 0.9, "text-background-padding": 5, "text-border-color": "#334155", "text-border-width": 1, width: 56, height: 56 } },
        { selector: 'node[label = "Person"]', style: { shape: "ellipse" } },
        { selector: 'node[label = "LiteralMeaning"]', style: { "background-color": "#38bdf8", shape: "round-rectangle" } },
        { selector: 'node[label = "IntendedMeaning"]', style: { "background-color": "#22c55e", shape: "round-rectangle" } },
        { selector: 'node[label = "Pattern"]', style: { "background-color": "#c026d3", shape: "octagon", width: 72, height: 72 } },
        { selector: 'node[label = "Tone"]', style: { "background-color": "#f97316", shape: "hexagon" } },
        { selector: 'node[label = "Expression"]', style: { "background-color": "#06b6d4", shape: "diamond" } },
        { selector: 'node[label = "Context"]', style: { "background-color": "#a855f7", shape: "round-rectangle" } },
        { selector: 'node[label = "Situation"]', style: { "background-color": "#64748b", shape: "round-rectangle", width: 90, height: 62 } },
        { selector: 'node[label = "SituationSignal"]', style: { "background-color": "#eab308", shape: "round-diamond" } },
        { selector: 'node[label = "SignalType"]', style: { "background-color": "#d97706", shape: "diamond", width: 64, height: 64 } },
        { selector: "edge", style: { width: 3, "line-color": "#9ca3af", "target-arrow-color": "#9ca3af", "target-arrow-shape": "triangle", "curve-style": "unbundled-bezier", "control-point-step-size": 35, label: "", "font-size": 13, "text-background-color": "#020617", "text-background-opacity": 0.95, "text-background-padding": 4, "text-rotation": "autorotate", color: "#e5e7eb" } },
        { selector: "edge.show-label", style: { label: "data(displayType)" } },
        { selector: "edge.channel-literal", style: { "line-color": "#60a5fa", "target-arrow-color": "#60a5fa" } },
        { selector: "edge.channel-inference", style: { "line-color": "#34d399", "target-arrow-color": "#34d399" } },
        { selector: 'edge[type = "HAS_LITERAL_MEANING"]', style: { "line-style": "dashed", width: 4 } },
        { selector: 'edge[type = "SUGGESTS"]', style: { "line-style": "dotted", width: 4 } },
        { selector: 'edge[type = "REQUIRES"]', style: { "line-style": "dashed", "line-color": "#94a3b8", "target-arrow-color": "#94a3b8", width: 2 } },
        { selector: 'edge.channel-pattern[type = "PREDICTS"]', style: { "line-style": "solid", width: 5, "line-color": "#fbbf24", "target-arrow-color": "#fbbf24" } },
        { selector: 'edge.channel-inference[type = "DERIVED_AS"]', style: { "line-style": "solid", width: 2, "line-color": "#a78bfa", "target-arrow-color": "#a78bfa" } },
        { selector: "edge:selected", style: { label: "data(displayType)", width: 3, "line-color": "#cbd5e1", "target-arrow-color": "#cbd5e1" } },
        { selector: "node.pattern-activated", style: { "background-color": "#f59e0b", "border-width": 4, "border-color": "#fde68a", "border-opacity": 1 } }
      ],
      layout: { name: "preset", positions: buildTypeLayeredPositions(elements), animate: false, fit: true, padding: 150 }
    });

    cy.batch(() => {
      cy.edges().forEach((edge) => {
        const channel = classifyChannel(edge.data("type"));
        edge.addClass(`channel-${channel}`);
        if (channel === "literal") edge.connectedNodes().addClass("node-literal");
        else if (channel === "inference") edge.connectedNodes().addClass("node-inference");
        else if (channel === "pattern") edge.connectedNodes().addClass("node-pattern");
      });
    });

    let selectedSituationNodeId = null;

    function getSituationSubgraph(nodeId) {
      const start = cy.getElementById(nodeId);
      if (start.empty()) return cy.collection();

      let owned = cy.collection().union(start);
      const queue = [start];
      while (queue.length > 0) {
        const node = queue.shift();
        node.connectedEdges().filter((e) => e.source().same(node)).forEach((edge) => {
          if (owned.has(edge)) return;
          owned = owned.union(edge);
          edge.target().forEach((n) => {
            if (!owned.has(n)) {
              owned = owned.union(n);
              queue.push(n);
            }
          });
        });
      }

      const situationSignalTypeIds = new Set(
        owned.nodes('[label = "SituationSignal"]')
          .connectedEdges()
          .filter((e) => e.data("type") === "INSTANCE_OF")
          .targets()
          .map((n) => n.id())
      );
      let subgraph = owned;

      cy.nodes('[label = "Pattern"]').forEach((pattern) => {
        const requiredSignals = pattern
          .connectedEdges()
          .filter((e) => e.source().same(pattern) && e.data("type") === "REQUIRES")
          .targets();
        const fullyActivated = requiredSignals.length > 0 &&
          requiredSignals.every((sig) => situationSignalTypeIds.has(sig.id()));

        if (fullyActivated) {
          subgraph = subgraph.union(pattern);
          pattern.connectedEdges().filter((e) => e.source().same(pattern)).forEach((edge) => {
            subgraph = subgraph.union(edge).union(edge.target());
          });
          pattern.addClass("pattern-activated");
        } else {
          pattern.removeClass("pattern-activated");
        }
      });

      return subgraph;
    }

    function applyFilters() {
      const showLiteral = document.getElementById("toggleLiteral").checked;
      const showInference = document.getElementById("toggleInference").checked;
      const showPattern = document.getElementById("togglePattern").checked;
      const showVocabulary = document.getElementById("toggleVocabulary").checked;
      let scope;

      if (selectedSituationNodeId) {
        scope = getSituationSubgraph(selectedSituationNodeId);
      } else {
        cy.nodes('[label = "Pattern"]').removeClass("pattern-activated");
        scope = cy.elements();
      }

      cy.batch(() => {
        cy.elements().not(scope).style("display", "none");
        scope.style("display", "element");
        scope.edges(".channel-literal").style("display", showLiteral ? "element" : "none");
        scope.edges(".channel-inference").style("display", showInference ? "element" : "none");
        scope.edges(".channel-pattern").style("display", showPattern ? "element" : "none");
        scope.edges(".channel-other").style("display", showLiteral || showInference ? "element" : "none");

        scope.nodes().forEach((node) => {
          const isLiteralNode = node.hasClass("node-literal");
          const isInferenceNode = node.hasClass("node-inference");
          const isPatternNode = node.hasClass("node-pattern");
          const showNode =
            (showLiteral && isLiteralNode) ||
            (showInference && isInferenceNode) ||
            (showPattern && isPatternNode) ||
            (!isLiteralNode && !isInferenceNode && !isPatternNode);
          if (!showNode) node.style("display", "none");
        });

        if (!showVocabulary) {
          scope.nodes('[label = "SignalType"]').style("display", "none");
          scope.edges('[type = "INSTANCE_OF"]').style("display", "none");
          scope.edges('[type = "REQUIRES"]').style("display", "none");
        }
      });

      const visible = cy.elements(":visible");
      if (visible.nonempty()) cy.fit(visible, 120);
    }

    function applyEdgeLabelVisibility() {
      const showEdgeLabels = document.getElementById("toggleEdgeLabels").checked;
      cy.batch(() => {
        if (showEdgeLabels) cy.edges().addClass("show-label");
        else cy.edges().removeClass("show-label");
      });
    }

    const select = document.getElementById("situationFilter");
    cy.nodes('[label = "Situation"]').forEach((node) => {
      const option = document.createElement("option");
      option.value = node.id();
      option.textContent = humanizeSituationLabel(node.data());
      select.appendChild(option);
    });

    select.addEventListener("change", () => {
      selectedSituationNodeId = select.value || null;
      applyFilters();
    });

    document.getElementById("toggleLiteral").addEventListener("change", applyFilters);
    document.getElementById("toggleInference").addEventListener("change", applyFilters);
    document.getElementById("togglePattern").addEventListener("change", applyFilters);
    document.getElementById("toggleVocabulary").addEventListener("change", applyFilters);
    document.getElementById("toggleEdgeLabels").addEventListener("change", applyEdgeLabelVisibility);

    applyFilters();
    applyEdgeLabelVisibility();
    cy.zoom(0.9);
    cy.center();
    setStatus("Static snapshot loaded successfully.");
  })
  .catch((error) => {
    setStatus(`Static graph load failed. ${error instanceof Error ? error.message : String(error)}`);
  });
"""


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def safe_json_for_html(data: object) -> str:
    return json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")


def build_static_html(graph_json: dict) -> str:
    tokens_css = read_text(APP_WEB_DIR / "tokens.css")
    styles_css = read_text(APP_WEB_DIR / "styles.css")

    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Social Situations Graph Demo</title>
  <style>
{tokens_css}

{styles_css}

#hint {{
  max-width: 980px;
}}

@media (max-width: 720px) {{
  #top-bar {{
    padding-right: var(--space-3);
  }}

  #controls {{
    gap: var(--space-2);
  }}

  label {{
    font-size: 13px;
  }}
}}
  </style>
  <script src="https://unpkg.com/cytoscape@3.30.0/dist/cytoscape.min.js"></script>
</head>
<body>
  <div id="app">
    <div id="top-bar">
      <div id="controls">
        <label><input id="toggleLiteral" type="checkbox" checked /> Literal channel</label>
        <label><input id="toggleInference" type="checkbox" checked /> Inference channel</label>
        <label><input id="togglePattern" type="checkbox" checked /> Pattern</label>
        <label><input id="toggleVocabulary" type="checkbox" /> Signal vocabulary</label>
        <label><input id="toggleEdgeLabels" type="checkbox" /> Edge labels</label>
        <label class="situation-filter-label">
          Situation:
          <select id="situationFilter"><option value="">All</option></select>
        </label>
      </div>
      <div id="hint">
        Static snapshot generated by the graph pipeline. Read top to bottom: observations → signals → patterns → intended meanings.
      </div>
    </div>

    <div id="cy"></div>
  </div>

  <script id="embedded-graph-data" type="application/json">{safe_json_for_html(graph_json)}</script>
  <script>
{STATIC_APP_JS}
  </script>
</body>
</html>
"""


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate a static root index.html for GitHub Pages using the exported Cytoscape graph snapshot."
    )
    parser.add_argument("--graph-json", required=True, help="Path to the exported Cytoscape JSON file.")
    parser.add_argument("--output-html", required=True, help="Path to the generated static index.html file.")
    args = parser.parse_args()

    graph_json_path = Path(args.graph_json).resolve()
    output_html_path = Path(args.output_html).resolve()

    graph_json = json.loads(graph_json_path.read_text(encoding="utf-8"))
    output_html_path.write_text(build_static_html(graph_json), encoding="utf-8")

    print(f"Generated static GitHub Pages entrypoint: {output_html_path}")


if __name__ == "__main__":
    main()
