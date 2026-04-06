import argparse
import os
import re
import random
import time
from datetime import datetime
from pathlib import Path

from anthropic import (
    Anthropic,
    APIConnectionError,
    APITimeoutError,
    InternalServerError,
    RateLimitError,
)


CYPHER_MARKER_START = "---NEO4J_CYPHER---"
CYPHER_MARKER_END = "---END_NEO4J_CYPHER---"
MD_MARKER_START = "---IMPLEMENTATION_MD---"
MD_MARKER_END = "---END_IMPLEMENTATION_MD---"

# Script lives under `graph_design/pipeline/`, so the repo root is 2 parents up.
_PROJECT_ROOT = Path(__file__).resolve().parents[2]
_DEFAULT_SPEC_PATH = _PROJECT_ROOT / "graph_design" / "spec" / "graph_specification.md"
_DEFAULT_OUTPUT_DIR = _PROJECT_ROOT / "graph_design" / "cypher"


def _load_dotenv_into_environ(dotenv_path: Path) -> None:
    """Load simple KEY=VALUE lines into os.environ (only if not already set)."""
    if not dotenv_path.is_file():
        return
    for raw_line in dotenv_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        k = k.strip()
        v = v.strip().strip('"').strip("'")
        if k and k not in os.environ:
            os.environ[k] = v


_load_dotenv_into_environ(_PROJECT_ROOT / ".env")


# ──────────────────────────────────────────────────────────────────────────────
# Cypher post-processing
# ──────────────────────────────────────────────────────────────────────────────

def fix_string_quotes(cypher: str) -> str:
    """
    Replace double-quoted string literals with single-quoted ones.

    Cypher requires single quotes for string literals; models occasionally emit
    double quotes.  The regex skips newlines so it never corrupts multi-line
    comments or swallows unrelated content.
    """
    def _replace(m: re.Match) -> str:
        return "'" + m.group(1).replace("'", "\\'") + "'"

    return re.sub(r'"([^"\n]*)"', _replace, cypher)


def enforce_statement_instance_model(cypher: str) -> str:
    """
    Enforce the per-utterance Statement identity rule:
    - Remove any uniqueness constraint on Statement.text (wrong: text is not
      a stable identifier in the instance model).
    - Ensure a uniqueness constraint on Statement.statementId exists.
    """
    text_unique_re = re.compile(
        r"CREATE\s+CONSTRAINT\b.*?FOR\s*\(\s*\w+\s*:\s*Statement\s*\)"
        r"\s*REQUIRE\s*\w+\.text\s+IS\s+UNIQUE\s*;",
        re.IGNORECASE | re.DOTALL,
    )
    stmt_id_re = re.compile(
        r"CREATE\s+CONSTRAINT\b.*?FOR\s*\(\s*\w+\s*:\s*Statement\s*\)"
        r"\s*REQUIRE\s*\w+\.statementId\s+IS\s+UNIQUE\s*;",
        re.IGNORECASE | re.DOTALL,
    )

    removed = bool(text_unique_re.search(cypher))
    cypher = text_unique_re.sub("", cypher)

    if removed and not stmt_id_re.search(cypher):
        insert = (
            "CREATE CONSTRAINT statement_id_unique IF NOT EXISTS\n"
            "  FOR (s:Statement) REQUIRE s.statementId IS UNIQUE;\n\n"
        )
        first_real = re.search(r"^(?!\s*//).+", cypher, re.MULTILINE)
        pos = first_real.start() if first_real else 0
        cypher = cypher[:pos] + insert + cypher[pos:]

    return cypher.strip() + "\n"


# ──────────────────────────────────────────────────────────────────────────────
# Extraction
# ──────────────────────────────────────────────────────────────────────────────

def extract_block(text: str, start_marker: str, end_marker: str) -> str | None:
    """Return the text between start_marker and end_marker, or None if absent."""
    start = text.find(start_marker)
    if start == -1:
        return None
    start += len(start_marker)
    end = text.find(end_marker, start)
    if end == -1:
        return None
    return text[start:end].strip()


def extract_cypher_from_fences(text: str) -> str | None:
    """
    Fallback extraction: pull content from ```cypher / ```cql fenced blocks.
    Used when the model returns valid Cypher but omits the delimiters.
    """
    matches = re.findall(r"```(?:cypher|cql)?\s*\n(.*?)```", text, re.DOTALL | re.IGNORECASE)
    cleaned = [m.strip() for m in matches if m.strip()]
    return "\n\n".join(cleaned) if cleaned else None


# ──────────────────────────────────────────────────────────────────────────────
# API helpers
# ──────────────────────────────────────────────────────────────────────────────

def message_to_text(msg) -> str:
    parts: list[str] = []
    for block in getattr(msg, "content", []) or []:
        txt = getattr(block, "text", None)
        if isinstance(txt, str) and txt.strip():
            parts.append(txt)
    return "\n\n".join(parts).strip()


def _is_retryable(err: Exception) -> bool:
    return isinstance(err, (RateLimitError, APIConnectionError, APITimeoutError, InternalServerError))


def create_message_with_retries(
    client: Anthropic,
    *,
    model: str,
    max_tokens: int,
    temperature: float,
    system: str,
    messages: list[dict],
    max_attempts: int,
    initial_backoff: float,
    max_backoff: float,
) -> object:
    for attempt in range(1, max_attempts + 1):
        try:
            return client.messages.create(
                model=model,
                max_tokens=max_tokens,
                temperature=temperature,
                system=system,
                messages=messages,
            )
        except Exception as err:  # noqa: BLE001
            if not _is_retryable(err) or attempt == max_attempts:
                raise
            base = min(max_backoff, initial_backoff * (2 ** (attempt - 1)))
            sleep = base * (0.85 + random.random() * 0.3)
            print(
                f"API error (attempt {attempt}/{max_attempts}): {err.__class__.__name__}. "
                f"Retrying in {sleep:.1f}s..."
            )
            time.sleep(sleep)


# ──────────────────────────────────────────────────────────────────────────────
# Prompts
# ──────────────────────────────────────────────────────────────────────────────

_SYSTEM_PROMPT = """\
You are an expert Neo4j engineer. Given a graph design specification in Markdown, \
produce a valid, executable Neo4j Cypher script and a short implementation document.

Your response MUST contain exactly two delimited blocks, in this order:

  ---NEO4J_CYPHER---
  <Cypher statements>
  ---END_NEO4J_CYPHER---

  ---IMPLEMENTATION_MD---
  <Markdown documentation>
  ---END_IMPLEMENTATION_MD---

Cypher rules — follow these exactly:

1. Use single quotes for ALL string literals. Never use double quotes for strings.

2. Every statement is completely self-contained and ends with exactly ONE semicolon.
   Never place a semicolon in the middle of a statement.

3. To create a relationship between two nodes, write one statement that re-finds
   both nodes with MATCH, then creates the relationship with MERGE:

     MATCH (a:Person {name: 'Alice'})
     MATCH (b:Statement {statementId: 'stmt_001'})
     MERGE (a)-[:SAID]->(b);

   Never use WITH to pass a variable from one statement into the next.

4. Use IF NOT EXISTS on every CREATE CONSTRAINT and CREATE INDEX statement.

5. Use MERGE (not CREATE) for both nodes and relationships, so the script is
   safe to re-run.

6. Do not add a uniqueness constraint on Statement.text.
   Use Statement.statementId for Statement uniqueness.

7. Do not invent node or relationship types not present in the spec.

The Markdown block must contain:
## 1. Interpreted graph design
## 2. Node types and properties
## 3. Relationship types
## 4. Constraints and indexes
## 5. Assumptions and ambiguities\
"""


def _build_user_prompt(spec_md: str) -> str:
    return (
        f"Graph design specification:\n\n{spec_md}\n\n"
        "Output the Cypher block first, then the Markdown documentation block."
    )


# ──────────────────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate Neo4j Cypher from a Markdown graph spec using Claude."
    )
    parser.add_argument("--input", default=str(_DEFAULT_SPEC_PATH),
                        help=f"Path to the Markdown spec. Default: {_DEFAULT_SPEC_PATH}")
    parser.add_argument("--output-dir", default=str(_DEFAULT_OUTPUT_DIR),
                        help="Directory to write outputs.")
    parser.add_argument("--model",
                        default=os.environ.get("CLAUDE_MODEL", "claude-sonnet-4-6"))
    parser.add_argument("--max-tokens", type=int,
                        default=int(os.environ.get("CLAUDE_MAX_TOKENS", "8000")))
    parser.add_argument("--temperature", type=float,
                        default=float(os.environ.get("CLAUDE_TEMPERATURE", "0.2")))
    parser.add_argument("--api-retries", type=int,
                        default=int(os.environ.get("CLAUDE_API_RETRIES", "5")))
    parser.add_argument("--api-initial-backoff", type=float,
                        default=float(os.environ.get("CLAUDE_API_INITIAL_BACKOFF_SECONDS", "2.0")))
    parser.add_argument("--api-max-backoff", type=float,
                        default=float(os.environ.get("CLAUDE_API_MAX_BACKOFF_SECONDS", "30.0")))
    args = parser.parse_args()

    input_path = Path(args.input).resolve()
    if not input_path.is_file():
        raise FileNotFoundError(f"Markdown spec not found: {input_path}")
    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    api_key = os.environ.get("ANTHROPIC_API_KEY") or os.environ.get("CLAUDE_API_KEY")
    if not api_key:
        raise RuntimeError("Set ANTHROPIC_API_KEY in your environment or .env file.")

    spec_md = input_path.read_text(encoding="utf-8")
    client = Anthropic(api_key=api_key)

    print(f"Calling Claude ({args.model}, max_tokens={args.max_tokens})...")
    msg = create_message_with_retries(
        client,
        model=args.model,
        max_tokens=args.max_tokens,
        temperature=args.temperature,
        system=_SYSTEM_PROMPT,
        messages=[{"role": "user", "content": _build_user_prompt(spec_md)}],
        max_attempts=max(1, args.api_retries),
        initial_backoff=max(0.1, args.api_initial_backoff),
        max_backoff=max(0.1, args.api_max_backoff),
    )

    content = message_to_text(msg)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M")

    # Extract Cypher — try delimiters first, fall back to fenced blocks.
    cypher = extract_block(content, CYPHER_MARKER_START, CYPHER_MARKER_END)
    if cypher is None:
        cypher = extract_cypher_from_fences(content)
    if cypher is None:
        raw_out = output_dir / f"{timestamp}_claude_raw_response.md"
        raw_out.write_text(content + "\n", encoding="utf-8")
        raise RuntimeError(
            f"No Cypher found in model response. Raw response saved to: {raw_out}"
        )

    cypher = fix_string_quotes(cypher)
    cypher = enforce_statement_instance_model(cypher)

    # Extract documentation — warn but don't fail if absent.
    impl_md = extract_block(content, MD_MARKER_START, MD_MARKER_END)
    if impl_md is None:
        impl_md = "No implementation documentation was returned by the model."
        print("Warning: Markdown documentation block not found; writing placeholder.")

    cypher_out = output_dir / f"{timestamp}_neo4j_implementation.cypher"
    md_out = output_dir / f"{timestamp}_NEO4J_SCHEMA.md"

    cypher_out.write_text(cypher, encoding="utf-8")
    md_out.write_text(impl_md + "\n", encoding="utf-8")

    print(f"Wrote: {cypher_out}")
    print(f"Wrote: {md_out}")
    print(f"Tokens used: {msg.usage.input_tokens} in / {msg.usage.output_tokens} out")


if __name__ == "__main__":
    main()
