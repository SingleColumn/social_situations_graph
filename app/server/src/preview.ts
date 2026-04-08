import { CytoscapeElement } from "./types.js";
import { ExtractedSignals } from "./extract.js";

type SignalData = { neoId: string; kind: string; valueId: string };
type PredictionData = { neoId: string; value: string; probability: number };

export type PreviewPatternRow = {
  matchedSignalData: SignalData[];
  patternNeoId: string;
  patternId: string;
  patternDescription: string;
  predictions: PredictionData[];
  requiredSignalTypes: SignalData[];
};

function virtualNode(id: string, label: string, props: Record<string, unknown> = {}): CytoscapeElement {
  return { data: { id, label, virtual: true, ...props } };
}

function edge(id: string, source: string, target: string, type: string, virtual = false): CytoscapeElement {
  return { data: { id, source, target, type, ...(virtual ? { virtual: true } : {}) } };
}

function realNode(neoId: string, label: string, props: Record<string, unknown> = {}): CytoscapeElement {
  return { data: { id: neoId, neo4jId: neoId, label, virtual: false, ...props } };
}

export function buildPreviewElements(
  signals: ExtractedSignals,
  patternRows: PreviewPatternRow[]
): CytoscapeElement[] {
  const elements: CytoscapeElement[] = [];
  const addedNodeIds = new Set<string>();

  const addNode = (el: CytoscapeElement) => {
    const id = String(el.data.id);
    if (!addedNodeIds.has(id)) {
      addedNodeIds.add(id);
      elements.push(el);
    }
  };

  // Virtual situation node
  addNode(virtualNode("preview_situation", "Situation", { situationId: "preview", description: "New situation preview" }));

  // Optional virtual person and statement nodes
  if (signals.speakerName) {
    addNode(virtualNode("preview_person", "Person", { name: signals.speakerName }));
    elements.push(edge("preview_edge_speaker", "preview_situation", "preview_person", "HAS_SPEAKER", true));
  }
  if (signals.statementText) {
    addNode(virtualNode("preview_statement", "Statement", { text: signals.statementText }));
    elements.push(edge("preview_edge_statement", "preview_situation", "preview_statement", "HAS_STATEMENT", true));
  }

  // Build one virtual SituationSignal per extracted signal, linked to its real SignalType
  const matchedSignalData = patternRows[0]?.matchedSignalData ?? [];

  for (const sig of signals.signals) {
    const signalId = `preview_sig_${sig.kind}_${sig.valueId.replace(/\s+/g, "_")}`;
    addNode(virtualNode(signalId, "SituationSignal", { kind: sig.kind, valueId: sig.valueId }));
    elements.push(edge(`preview_edge_has_signal_${signalId}`, "preview_situation", signalId, "HAS_SIGNAL", true));

    // Link to the real SignalType node if it was resolved from Neo4j
    const resolved = matchedSignalData.find(s => s.kind === sig.kind && s.valueId === sig.valueId);
    if (resolved) {
      addNode(realNode(resolved.neoId, "SignalType", { kind: resolved.kind, valueId: resolved.valueId }));
      elements.push(edge(`preview_edge_instance_of_${signalId}`, signalId, resolved.neoId, "INSTANCE_OF", true));
    }
  }

  // Add real Pattern, IntendedMeaning nodes and their connections
  for (const row of patternRows) {
    addNode(realNode(row.patternNeoId, "Pattern", {
      patternId: row.patternId,
      description: row.patternDescription,
    }));

    // Pattern → REQUIRES → SignalType edges
    for (const req of row.requiredSignalTypes) {
      addNode(realNode(req.neoId, "SignalType", { kind: req.kind, valueId: req.valueId }));
      elements.push(edge(
        `preview_edge_requires_${row.patternNeoId}_${req.neoId}`,
        row.patternNeoId, req.neoId, "REQUIRES"
      ));
    }

    // Pattern → PREDICTS → IntendedMeaning edges
    for (const pred of row.predictions) {
      if (!pred.neoId || !pred.value) continue;
      addNode(realNode(pred.neoId, "IntendedMeaning", { value: pred.value }));
      elements.push(edge(
        `preview_edge_predicts_${row.patternNeoId}_${pred.neoId}`,
        row.patternNeoId, pred.neoId, "PREDICTS",
        false
      ));
    }
  }

  return elements;
}
