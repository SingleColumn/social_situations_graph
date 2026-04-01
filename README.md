# Social Situations Graph Demo

Local TypeScript demo showing how an LLM can help query an existing Neo4j social interpretation graph.

## What this app does

- Visualizes the whole graph in Cytoscape.
- Accepts a natural-language social situation from the user.
- Runs an allowlisted Cypher template against Neo4j.
- Uses Anthropic Sonnet to summarize likely interpretations.
- Falls back to deterministic scoring if Anthropic is unavailable.

## Project layout
- `app/server/src/index.ts` - API server and static file hosting
- `app/server/src/neo4j.ts` - Neo4j driver/session helpers
- `app/server/src/queries.ts` - allowlisted Cypher templates
- `app/server/src/interpret.ts` - interpretation orchestration
- `app/server/src/anthropic.ts` - Sonnet client + response parsing
- `app/web/index.html` - UI shell (graph + textbox + results)
- `app/web/app.js` - frontend behavior and Cytoscape wiring
- `app/web/tokens.css`, `app/web/styles.css` - token-driven styling

## Environment variables

Set these in `.env`:

- `NEO4J_URI`
- `NEO4J_USER`
- `NEO4J_PASSWORD`
- `NEO4J_DATABASE`
- `ANTHROPIC_API_KEY` (optional but recommended)

## Run locally

1. Install dependencies:
   - `npm install`
2. Start the app:
   - `npm run dev`
3. Open:
   - `http://localhost:3000`

## API endpoints

- `GET /api/graph/full` -> returns Cytoscape-compatible graph elements from Neo4j
- `POST /api/interpret` -> accepts `{ "situation": "..." }` and returns ranked interpretations
- `GET /api/health` -> simple health check

## Notes

- Neo4j is the source of truth; the old JSON export is no longer required for runtime graph loading.
- For demo safety and predictability, only predefined Cypher templates are executed.
