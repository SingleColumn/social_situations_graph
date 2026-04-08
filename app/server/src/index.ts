import dotenv from "dotenv";
import express from "express";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { closeNeo4j, runCypher } from "./neo4j.js";
import { interpretSituation } from "./interpret.js";
import { interpretRequestSchema } from "./types.js";
import { extractSignalTypes } from "./extract.js";
import { previewQuery } from "./queries.js";
import { buildPreviewElements, PreviewPatternRow } from "./preview.js";

dotenv.config();

const app = express();
app.use(express.json());

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
// `__dirname` is different in dev (`app/server/src`) vs compiled output (`dist/server/src`).
// From both locations, `../../../` resolves back to the repo root.
const projectRoot = path.resolve(__dirname, "../../../");

const webDirCandidates = [path.join(projectRoot, "app", "web"), path.join(projectRoot, "web")];
const webDir =
  webDirCandidates.find((dir) => fs.existsSync(path.join(dir, "index.html"))) ?? webDirCandidates[0];

app.use(express.static(webDir));

app.get("/api/health", (_req, res) => {
  res.json({ ok: true });
});

app.get("/api/graph/full", async (_req, res) => {
  try {
    const rows = await runCypher<{
      id: string;
      labels: string[];
      props: Record<string, unknown>;
    }>(
      `MATCH (n)
       RETURN elementId(n) AS id, labels(n) AS labels, properties(n) AS props`
    );

    const edgeRows = await runCypher<{
      id: string;
      type: string;
      source: string;
      target: string;
      props: Record<string, unknown>;
    }>(
      `MATCH ()-[r]->()
       RETURN elementId(r) AS id, type(r) AS type,
              elementId(startNode(r)) AS source,
              elementId(endNode(r)) AS target,
              properties(r) AS props`
    );

    const nodes = rows.map((row) => ({
      data: {
        id: row.id,
        neo4jId: row.id,
        label: row.labels?.[0] || "Node",
        ...row.props
      }
    }));

    const edges = edgeRows.map((row) => ({
      data: {
        id: row.id,
        source: row.source,
        target: row.target,
        type: row.type,
        ...row.props
      }
    }));

    res.json({ elements: [...nodes, ...edges] });
  } catch (error) {
    res.status(500).json({
      error: "Failed to load graph from Neo4j.",
      details: error instanceof Error ? error.message : String(error)
    });
  }
});

app.get("/api/graph/situations", async (_req, res) => {
  try {
    const rows = await runCypher<{
      id: string;
      props: Record<string, unknown>;
    }>(
      `MATCH (s:Situation)
       RETURN elementId(s) AS id, properties(s) AS props
       ORDER BY s.situationId`
    );
    res.json({ situations: rows });
  } catch (error) {
    res.status(500).json({
      error: "Failed to load situations from Neo4j.",
      details: error instanceof Error ? error.message : String(error)
    });
  }
});

app.post("/api/interpret", async (req, res) => {
  const parse = interpretRequestSchema.safeParse(req.body);
  if (!parse.success) {
    return res.status(400).json({ error: parse.error.flatten() });
  }

  try {
    const result = await interpretSituation(parse.data.situation);
    return res.json(result);
  } catch (error) {
    return res.status(500).json({
      error: "Failed to interpret the situation.",
      details: error instanceof Error ? error.message : String(error)
    });
  }
});

app.post("/api/scenario/preview", async (req, res) => {
  const parse = interpretRequestSchema.safeParse(req.body);
  if (!parse.success) {
    return res.status(400).json({ error: parse.error.flatten() });
  }

  try {
    const signals = await extractSignalTypes(parse.data.situation);
    const patternRows = await runCypher<PreviewPatternRow>(previewQuery, { signals: signals.signals });
    const elements = buildPreviewElements(signals, patternRows);
    return res.json({ elements });
  } catch (error) {
    return res.status(500).json({
      error: "Failed to build scenario preview.",
      details: error instanceof Error ? error.message : String(error)
    });
  }
});

app.use((_req, res) => {
  res.sendFile(path.join(webDir, "index.html"));
});

const port = Number(process.env.PORT || 3000);
const server = app.listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`Server running at http://localhost:${port}`);
});

for (const sig of ["SIGINT", "SIGTERM"] as const) {
  process.on(sig, async () => {
    server.close();
    await closeNeo4j();
    process.exit(0);
  });
}
