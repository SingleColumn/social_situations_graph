function prettifyType(type) {
  if (!type) return "";
  return String(type).replace(/_/g, " ");
}

function fallbackLabel(data) {
  if (!data) return "";
  if (data.neo4jId) return String(data.neo4jId);
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
  if (nodeType === "Signal") {
    const kind = data.kind || "signal";
    const valueId = data.valueId || fallbackLabel(data);
    return `Signal: ${kind} / ${valueId}`;
  }
  if (nodeType === "Situation") {
    return humanizeSituationLabel(data);
  }
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
  const typeOrder = ["Situation", "Person", "Statement", "LiteralMeaning", "Tone", "Expression", "Context", "Signal", "Pattern", "IntendedMeaning"];
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
  const inferenceTypes = new Set(["HAS_SIGNAL", "SUGGESTS", "DERIVED_AS", "REQUIRES", "PREDICTS"]);
  if (literalTypes.has(edgeType)) return "literal";
  if (inferenceTypes.has(edgeType)) return "inference";
  return "other";
}

function renderInterpretations(payload) {
  const target = document.getElementById("results");
  target.innerHTML = "";

  if (!payload?.interpretations?.length) {
    target.innerHTML = `<div class="muted">No interpretations found for this input yet.</div>`;
    return;
  }

  for (const interpretation of payload.interpretations) {
    const card = document.createElement("article");
    card.className = "result-card";
    card.innerHTML = `
      <h4>${interpretation.title}</h4>
      <p>${interpretation.rationale}</p>
      <span class="chip">confidence ${(interpretation.confidence * 100).toFixed(0)}%</span>
    `;
    target.appendChild(card);
  }

  if (payload.warnings?.length) {
    const warning = document.createElement("div");
    warning.className = "muted";
    warning.textContent = payload.warnings.join(" ");
    target.appendChild(warning);
  }
}

async function submitSituation(event) {
  event.preventDefault();
  const input = document.getElementById("situationInput");
  const button = document.getElementById("submitButton");
  const value = input.value.trim();
  if (!value) return;

  button.disabled = true;
  button.textContent = "Interpreting...";

  try {
    const response = await fetch("/api/interpret", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ situation: value })
    });
    const payload = await response.json();
    if (!response.ok) {
      throw new Error(payload?.error || "Interpretation request failed.");
    }
    renderInterpretations(payload);
  } catch (error) {
    renderInterpretations({
      interpretations: [],
      warnings: [error instanceof Error ? error.message : String(error)]
    });
  } finally {
    button.disabled = false;
    button.textContent = "Interpret Situation";
  }
}

fetch(`/api/graph/full?v=${Date.now()}`, { cache: "no-store" })
  .then((res) => res.json())
  .then((graph) => {
    if (!Array.isArray(graph?.elements) || graph.elements.length === 0) {
      const results = document.getElementById("results");
      if (results) {
        results.innerHTML = `<div class="muted">Graph is empty - run pipeline first.</div>`;
      }
      return;
    }

    const elements = enrichElements(graph.elements);
    const cy = cytoscape({
      container: document.getElementById("cy"),
      elements,
      minZoom: 0.35,
      maxZoom: 3.5,
      wheelSensitivity: 0.15,
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
        { selector: 'node[label = "Signal"]', style: { "background-color": "#eab308", shape: "round-diamond" } },
        { selector: "edge", style: { width: 3, "line-color": "#9ca3af", "target-arrow-color": "#9ca3af", "target-arrow-shape": "triangle", "curve-style": "unbundled-bezier", "control-point-step-size": 35, label: "", "font-size": 13, "text-background-color": "#020617", "text-background-opacity": 0.95, "text-background-padding": 4, "text-rotation": "autorotate", color: "#e5e7eb" } },
        { selector: "edge.show-label", style: { label: "data(displayType)" } },
        { selector: "edge.channel-literal", style: { "line-color": "#60a5fa", "target-arrow-color": "#60a5fa" } },
        { selector: "edge.channel-inference", style: { "line-color": "#34d399", "target-arrow-color": "#34d399" } },
        { selector: 'edge[type = "HAS_LITERAL_MEANING"]', style: { "line-style": "dashed", width: 4 } },
        { selector: 'edge[type = "SUGGESTS"]', style: { "line-style": "dotted", width: 4 } },
        { selector: 'edge[type = "REQUIRES"]', style: { "line-style": "dashed", "line-color": "#94a3b8", "target-arrow-color": "#94a3b8", width: 2 } },
        { selector: 'edge.channel-inference[type = "PREDICTS"]', style: { "line-style": "solid", width: 5, "line-color": "#fbbf24", "target-arrow-color": "#fbbf24" } },
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
      });
    });

    let selectedSituationNodeId = null;

    function getSituationSubgraph(nodeId) {
      const start = cy.getElementById(nodeId);
      if (start.empty()) return cy.collection();

      // Phase 1: collect situation-owned nodes via outgoing edges only.
      // No REQUIRES back-traversal here — this gives us only the signals
      // that genuinely belong to this situation.
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

      // Phase 2: include only Patterns whose every REQUIRES target is among
      // this situation's own signals (fully activated patterns).
      const situationSignalIds = new Set(owned.nodes('[label = "Signal"]').map((n) => n.id()));
      let subgraph = owned;

      cy.nodes('[label = "Pattern"]').forEach((pattern) => {
        const requiredSignals = pattern
          .connectedEdges()
          .filter((e) => e.source().same(pattern) && e.data("type") === "REQUIRES")
          .targets();
        const fullyActivated = requiredSignals.length > 0 &&
          requiredSignals.every((sig) => situationSignalIds.has(sig.id()));

        if (fullyActivated) {
          subgraph = subgraph.union(pattern);
          // Include the REQUIRES edges (back to this situation's signals) and PREDICTS edges + targets.
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
        scope.edges(".channel-other").style("display", showLiteral || showInference ? "element" : "none");
        scope.nodes().forEach((node) => {
          const isLiteralNode = node.hasClass("node-literal");
          const isInferenceNode = node.hasClass("node-inference");
          const showNode = (showLiteral && isLiteralNode) || (showInference && isInferenceNode) || (!isLiteralNode && !isInferenceNode);
          if (!showNode) node.style("display", "none");
        });
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
    document.getElementById("toggleEdgeLabels").addEventListener("change", applyEdgeLabelVisibility);
    document.getElementById("toggleInterpret").addEventListener("change", (e) => {
      document.getElementById("interpret-panel").classList.toggle("hidden", !e.target.checked);
    });
    applyFilters();
    applyEdgeLabelVisibility();
    cy.zoom(0.9);
    cy.center();
  })
  .catch((err) => console.error("Error loading graph:", err));

document.getElementById("interpretForm").addEventListener("submit", submitSituation);
