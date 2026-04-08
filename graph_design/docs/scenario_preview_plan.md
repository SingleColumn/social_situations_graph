# Plan: ephemeral scenario preview

Add the ability for a user to describe a new scenario in natural language and visualize it as a temporary graph — showing which patterns from the real graph would apply — without writing anything to Neo4j.

---

## Architecture summary

The LLM maps the user's input onto the existing SignalType vocabulary. A read-only Neo4j query finds matching patterns. Virtual Cytoscape elements are assembled and returned to the frontend for rendering. Nothing is persisted.

```
User input (natural language)
  → Claude: extract signal types mapped to existing vocabulary
  → Neo4j (read-only): find Pattern + IntendedMeaning nodes that match
  → assemble virtual Cytoscape elements
  → frontend renders preview with visual distinction
```

---

## Parts

### Part 1 — Discover the existing SignalType vocabulary
**No code changes.** Query Neo4j or read the graph spec to list all `SignalType` nodes (`kind` + `valueId`). This produces the reference list Claude needs in Part 2.

- [x] List all `SignalType` values from the spec or a live Neo4j query
- [x] Confirm the set is stable enough to hardcode in the extraction prompt

---

### Part 2 — Claude signal extraction (isolated)
New function: takes a natural language scenario + the SignalType vocabulary, returns structured signal types mapped to existing `valueId` values.

- [x] Create `app/server/src/extract.ts`
- [x] Write `extractSignalTypes(situation: string): Promise<ExtractedSignals>`

---

### Part 3 — Read-only pattern-matching query
New Cypher query: given a list of `SignalType` `valueId`s, find matching `Pattern` → `PREDICTS` → `IntendedMeaning` chains.

- [x] Add `previewQuery` to `queries.ts`

---

### Part 4 — Virtual Cytoscape element assembly
New function: takes extracted signals + pattern rows, builds a Cytoscape-compatible elements array. Virtual nodes carry a flag to distinguish them from persisted nodes.

- [x] Create `app/server/src/preview.ts` with `buildPreviewElements`
- [x] Virtual nodes carry `virtual: true`; real nodes carry `virtual: false`

---

### Part 5 — New API endpoint
Wire Parts 2, 3, and 4 together.

- [x] Add `POST /api/scenario/preview` to `index.ts`

---

### Part 6 — Frontend preview rendering
Add a text input to the UI and render the preview in the existing Cytoscape instance with visual distinction for virtual nodes.

- [x] Add toggle + panel to `index.html`
- [x] Add `submitPreview` and `clearPreview` to `app.js`
- [x] Virtual nodes: dashed border; existing nodes dimmed during preview

---

## Sequencing rationale

Part 2 is the highest-risk piece — if Claude maps signal types unreliably, the rest doesn't matter. Isolating and testing it early gives a go/no-go signal at minimal cost. Each subsequent part can be verified independently before the next depends on it.
