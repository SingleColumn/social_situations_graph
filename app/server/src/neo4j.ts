import neo4j, { Driver } from "neo4j-driver";
import dotenv from "dotenv";

dotenv.config();

const uri = process.env.NEO4J_URI;
const user = process.env.NEO4J_USER;
const password = process.env.NEO4J_PASSWORD;
export const database = process.env.NEO4J_DATABASE || "neo4j";

if (!uri || !user || !password) {
  throw new Error("Missing Neo4j env vars. Set NEO4J_URI, NEO4J_USER, and NEO4J_PASSWORD.");
}

const resolvedUri =
  uri.startsWith("neo4j://localhost") || uri.startsWith("neo4j://127.0.0.1")
    ? uri.replace("neo4j://", "bolt://")
    : uri;

export const neo4jDriver: Driver = neo4j.driver(resolvedUri, neo4j.auth.basic(user, password));
const fallbackDatabase = "neo4j";

function normalizeValue(value: unknown): unknown {
  if (neo4j.isInt(value)) {
    return value.toNumber();
  }
  if (Array.isArray(value)) {
    return value.map((item) => normalizeValue(item));
  }
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>).map(([key, item]) => [key, normalizeValue(item)])
    );
  }
  return value;
}

export async function runCypher<T = Record<string, unknown>>(
  cypher: string,
  params: Record<string, unknown> = {}
): Promise<T[]> {
  const runWithDatabase = async (db: string): Promise<T[]> => {
    const session = neo4jDriver.session({ database: db });
    try {
      const result = await session.run(cypher, params);
      return result.records.map((record) => normalizeValue(record.toObject()) as T);
    } finally {
      await session.close();
    }
  };

  try {
    return await runWithDatabase(database);
  } catch (error) {
    const neo4jError = error as { code?: string };
    const isMissingDatabase = neo4jError.code === "Neo.ClientError.Database.DatabaseNotFound";
    const canFallback = database !== fallbackDatabase && isMissingDatabase;

    if (!canFallback) {
      throw error;
    }

    return runWithDatabase(fallbackDatabase);
  }
}

export async function closeNeo4j(): Promise<void> {
  await neo4jDriver.close();
}
