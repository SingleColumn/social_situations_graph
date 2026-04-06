import argparse
from pathlib import Path

from neo4j import GraphDatabase
from neo4j.exceptions import AuthError, ClientError, ServiceUnavailable


def split_cypher_statements(text: str) -> list[str]:
    """
    Split a Cypher script into individual statements by `;`.

    This is a best-effort splitter that avoids breaking on semicolons inside
    single-quoted, double-quoted, or backtick-quoted strings.
    """
    statements: list[str] = []
    buf: list[str] = []

    in_single = False
    in_double = False
    in_backtick = False
    in_line_comment = False

    i = 0
    while i < len(text):
        ch = text[i]

        # Handle line comments (Neo4j uses `//`), so we don't split on `;`
        # inside comments.
        if not in_single and not in_double and not in_backtick and not in_line_comment:
            if ch == "/" and i + 1 < len(text) and text[i + 1] == "/":
                in_line_comment = True
                buf.append("//")
                i += 2
                continue

        if in_line_comment:
            buf.append(ch)
            if ch == "\n":
                in_line_comment = False
            i += 1
            continue

        # Toggle quote modes when we see an opening/closing quote and we're not
        # inside a different quote type.
        if ch == "'" and not in_double and not in_backtick:
            # Handle escaped quotes like \'
            if in_single and i > 0 and text[i - 1] == "\\":
                buf.append(ch)
            else:
                in_single = not in_single
                buf.append(ch)
        elif ch == '"' and not in_single and not in_backtick:
            if in_double and i > 0 and text[i - 1] == "\\":
                buf.append(ch)
            else:
                in_double = not in_double
                buf.append(ch)
        elif ch == "`" and not in_single and not in_double:
            in_backtick = not in_backtick
            buf.append(ch)
        elif ch == ";" and not in_single and not in_double and not in_backtick:
            stmt = "".join(buf).strip()
            if stmt:
                statements.append(stmt)
            buf = []
        else:
            buf.append(ch)

        i += 1

    tail = "".join(buf).strip()
    if tail:
        statements.append(tail)

    return statements


def is_comment_only_statement(stmt: str) -> bool:
    cleaned = stmt.strip()
    if not cleaned:
        return True

    for line in cleaned.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if not stripped.startswith("//"):
            return False
    return True


def safe_for_console(text: str) -> str:
    # Windows terminals often default to cp1252; keep output ASCII-only to avoid UnicodeEncodeError.
    return "".join(ch if ord(ch) < 128 else "?" for ch in text)


def main() -> None:
    parser = argparse.ArgumentParser(description="Load a Cypher script into Neo4j via neo4j-driver.")
    parser.add_argument("--input", required=True, help="Path to .cypher file")
    parser.add_argument("--uri", default="neo4j://localhost:7687")
    parser.add_argument("--user", default="neo4j")
    parser.add_argument("--password", default="")
    parser.add_argument("--database", default="neo4j", help="Neo4j database name")
    parser.add_argument("--continue-on-error", action="store_true", help="Continue executing remaining statements on error")
    args = parser.parse_args()

    input_path = Path(args.input).resolve()
    if not input_path.is_file():
        raise FileNotFoundError(f"Cypher file not found: {input_path}")

    text = input_path.read_text(encoding="utf-8")
    statements = [s for s in split_cypher_statements(text) if not is_comment_only_statement(s)]
    if not statements:
        raise RuntimeError(f"No Cypher statements found in {input_path}")

    driver = GraphDatabase.driver(args.uri, auth=(args.user, args.password))

    try:
        def execute_with_session(session) -> None:
            print(f"Executing {len(statements)} Cypher statement(s) from {input_path.name}...")
            for idx, stmt in enumerate(statements, start=1):
                stmt_preview = safe_for_console(" ".join(stmt.split())[:200])
                try:
                    session.run(stmt).consume()
                    print(f"[{idx}/{len(statements)}] OK: {stmt_preview}...")
                except Exception as e:  # noqa: BLE001 - we want the raw driver error
                    err_str = str(e)
                    lowered = err_str.lower()

                    # Let the caller handle database-not-found by retrying on the
                    # default database.
                    if ("databasenotfound" in lowered) or ("graph reference not found" in lowered):
                        raise

                    # Schema-already-exists errors are idempotent: the desired
                    # constraint or index is already present, so treat as a warning.
                    _schema_already_exists = (
                        "ConstraintAlreadyExists" in err_str
                        or "IndexAlreadyExists" in err_str
                        or "EquivalentSchemaRuleAlreadyExists" in err_str
                        or "conflicting constraint already exists" in lowered
                        or "equivalent index already exists" in lowered
                    )
                    if _schema_already_exists:
                        print(f"[{idx}/{len(statements)}] SKIP (already exists): {stmt_preview}...")
                        continue

                    msg = f"[{idx}/{len(statements)}] FAILED: {stmt_preview}...\n{safe_for_console(err_str)}"
                    if args.continue_on_error:
                        print(msg)
                        continue
                    raise RuntimeError(msg) from e

        if args.database:
            try:
                with driver.session(database=args.database) as session:
                    execute_with_session(session)
            except ClientError as e:
                # If the named database doesn't exist, retry against Neo4j's default database.
                # (Neo4j Desktop and some hosted setups often only expose `neo4j` by default.)
                if "DatabaseNotFound" in str(e):
                    print(f"Database '{args.database}' not found; retrying with the default database...")
                    with driver.session() as session:
                        execute_with_session(session)
                else:
                    raise
        else:
            with driver.session() as session:
                execute_with_session(session)
    except ServiceUnavailable as e:
        raise RuntimeError(f"Neo4j unavailable at {args.uri}. Is Bolt enabled and the DB running?\n{e}") from e
    except AuthError as e:
        raise RuntimeError(f"Neo4j authentication failed for user '{args.user}'.\n{e}") from e
    finally:
        driver.close()


if __name__ == "__main__":
    main()

