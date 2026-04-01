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
    OverloadedError,
    RateLimitError,
)


NEO4J_CYPHER_MARKER_START = "---NEO4J_CYPHER---"
NEO4J_CYPHER_MARKER_END = "---END_NEO4J_CYPHER---"
MD_MARKER_START = "---IMPLEMENTATION_MD---"
MD_MARKER_END = "---END_IMPLEMENTATION_MD---"

# Script lives under `graph/pipeline/`, so the repo root is 2 parents up.
_PROJECT_ROOT = Path(__file__).resolve().parents[2]

# Default graph spec + output directory.
_DEFAULT_SPEC_PATH = _PROJECT_ROOT / "graph" / "spec" / "graph_specification.md"
_DEFAULT_OUTPUT_DIR = _PROJECT_ROOT / "graph" / "cypher"


def _load_dotenv_into_environ(dotenv_path: Path) -> None:
    """Load simple KEY=VALUE lines into `os.environ` (only if not already set)."""
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


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def extract_block(text: str, start_marker: str, end_marker: str) -> str | None:
    pattern = re.compile(
        re.escape(start_marker) + r"(.*?)" + re.escape(end_marker),
        re.DOTALL,
    )
    m = pattern.search(text)
    if not m:
        return None
    return m.group(1).strip()


def extract_block_flexible(text: str, start_marker: str, end_marker: str) -> str | None:
    # Primary path: exact markers.
    block = extract_block(text, start_marker, end_marker)
    if block:
        return block

    # Secondary path: markers wrapped with whitespace / backticks.
    marker_pattern = re.compile(
        rf"`?\s*{re.escape(start_marker)}\s*`?(.*?)`?\s*{re.escape(end_marker)}\s*`?",
        re.DOTALL | re.IGNORECASE,
    )
    m = marker_pattern.search(text)
    if m:
        return m.group(1).strip()

    return None


def extract_md_by_sections(text: str) -> str | None:
    # Final fallback if marker block is missing: collect requested sections.
    sections = [
        "## 1. Interpreted graph design",
        "## 2. Neo4j schema mapping",
        "## 3. Constraints and indexes (Cypher)",
        "## 4. Sample data load (Cypher)",
        "## 5. Validation queries (Cypher)",
        "## 6. Assumptions and ambiguities",
    ]

    if not all(s in text for s in sections):
        return None

    start = text.find(sections[0])
    if start == -1:
        return None
    return text[start:].strip()


def extract_cypher_fallback(text: str) -> str | None:
    # Fallback path 0: start marker exists, end marker missing (truncated response).
    start_idx = text.find(NEO4J_CYPHER_MARKER_START)
    if start_idx != -1:
        after_start = text[start_idx + len(NEO4J_CYPHER_MARKER_START) :]
        # If markdown marker exists, stop before it; otherwise consume to EOF.
        md_idx = after_start.find(MD_MARKER_START)
        if md_idx != -1:
            after_start = after_start[:md_idx]
        truncated_block = after_start.strip()
        if truncated_block:
            return truncated_block

    # Fallback if marker block is missing: pull all cypher fenced blocks.
    matches = re.findall(r"```(?:cypher|cql)?\s*\n(.*?)```", text, re.DOTALL | re.IGNORECASE)
    cleaned = [m.strip() for m in matches if m.strip()]
    if cleaned:
        return "\n\n".join(cleaned)
    return None


def build_impl_md_fallback(raw_text: str, cypher: str | None) -> str:
    """Create a usable implementation markdown when section markers are missing."""
    body = raw_text.strip() or "No explanatory markdown was returned by the model."
    cypher_block = cypher.strip() if cypher else "No Cypher block extracted."
    return (
        "## 1. Interpreted graph design\n"
        "Model returned output in an unexpected format. Preserving response below.\n\n"
        f"{body}\n\n"
        "## 2. Neo4j schema mapping\n"
        "See Cypher statements below.\n\n"
        "## 3. Constraints and indexes (Cypher)\n"
        "See extracted Cypher file.\n\n"
        "## 4. Sample data load (Cypher)\n"
        "See extracted Cypher file.\n\n"
        "## 5. Validation queries (Cypher)\n"
        "See extracted Cypher file.\n\n"
        "## 6. Assumptions and ambiguities\n"
        "The model did not return the requested markdown marker block; fallback document generated.\n\n"
        "```cypher\n"
        f"{cypher_block}\n"
        "```"
    )


def message_to_text(msg) -> str:
    parts: list[str] = []
    for block in getattr(msg, "content", []) or []:
        txt = getattr(block, "text", None)
        if isinstance(txt, str) and txt.strip():
            parts.append(txt)
    return "\n\n".join(parts).strip()


def _is_retryable_anthropic_error(err: Exception) -> bool:
    """
    Retry on transient API failures:
    - overloaded / rate-limited responses
    - transport-level failures
    - server-side 5xx responses
    """
    return isinstance(err, (RateLimitError, OverloadedError, APIConnectionError, APITimeoutError, InternalServerError))


def create_message_with_retries(
    client: Anthropic,
    *,
    model: str,
    max_tokens: int,
    temperature: float,
    system: str,
    messages: list[dict],
    max_attempts: int,
    initial_backoff_seconds: float,
    max_backoff_seconds: float,
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
            if not _is_retryable_anthropic_error(err) or attempt == max_attempts:
                raise

            # Exponential backoff with jitter, capped.
            base_sleep = min(max_backoff_seconds, initial_backoff_seconds * (2 ** (attempt - 1)))
            sleep_seconds = base_sleep * (0.85 + random.random() * 0.3)
            print(
                f"Anthropic request failed (attempt {attempt}/{max_attempts}): {err.__class__.__name__}. "
                f"Retrying in {sleep_seconds:.1f}s..."
            )
            time.sleep(sleep_seconds)


def normalize_statement_instance_model(cypher: str) -> str:
    """
    Enforce statement-instance modeling:
    - remove uniqueness constraints on Statement.text
    - ensure a uniqueness constraint on Statement.statementId exists
    """
    text_unique_stmt_re = re.compile(
        r"CREATE\s+CONSTRAINT\b.*?FOR\s*\(\s*\w+\s*:\s*Statement\s*\)\s*REQUIRE\s*\w+\.text\s+IS\s+UNIQUE\s*;",
        re.IGNORECASE | re.DOTALL,
    )
    statement_id_unique_re = re.compile(
        r"CREATE\s+CONSTRAINT\b.*?FOR\s*\(\s*\w+\s*:\s*Statement\s*\)\s*REQUIRE\s*\w+\.statementId\s+IS\s+UNIQUE\s*;",
        re.IGNORECASE | re.DOTALL,
    )

    removed_text_unique = bool(text_unique_stmt_re.search(cypher))
    normalized = text_unique_stmt_re.sub("", cypher)
    has_statement_id_unique = bool(statement_id_unique_re.search(normalized))

    if removed_text_unique and not has_statement_id_unique:
        statement_id_constraint = (
            "\nCREATE CONSTRAINT statement_id_unique IF NOT EXISTS\n"
            "  FOR (s:Statement) REQUIRE s.statementId IS UNIQUE;\n"
        )
        # Keep constraints grouped near the top if possible.
        first_non_comment = re.search(r"^(?!\s*//).+", normalized, re.MULTILINE)
        if first_non_comment:
            insert_at = first_non_comment.start()
            normalized = normalized[:insert_at] + statement_id_constraint + normalized[insert_at:]
        else:
            normalized = statement_id_constraint + normalized

    return normalized.strip() + "\n"


def main():
    parser = argparse.ArgumentParser(
        description="Generate Neo4j Cypher + implementation markdown from a graph design markdown spec using Claude."
    )
    parser.add_argument(
        "--input",
        default=str(_DEFAULT_SPEC_PATH),
        help=(
            "Path to the markdown spec file. "
            f"Default: {_DEFAULT_SPEC_PATH}."
        ),
    )
    parser.add_argument(
        "--output-dir",
        default=str(_DEFAULT_OUTPUT_DIR),
        help="Directory to write outputs (neo4j_implementation.cypher and NEO4J_SCHEMA.md).",
    )
    parser.add_argument(
        "--model",
        default=os.environ.get("CLAUDE_MODEL", "claude-sonnet-4-6"),
        help="Claude model name. If the default is wrong for your account, set it correctly.",
    )
    parser.add_argument(
        "--max-tokens",
        type=int,
        default=int(os.environ.get("CLAUDE_MAX_TOKENS", "6000")),
        help="Max tokens for the response.",
    )
    parser.add_argument(
        "--temperature",
        type=float,
        default=float(os.environ.get("CLAUDE_TEMPERATURE", "0.2")),
        help="Sampling temperature.",
    )
    parser.add_argument(
        "--api-retries",
        type=int,
        default=int(os.environ.get("CLAUDE_API_RETRIES", "5")),
        help="Max retry attempts for transient Anthropic API failures.",
    )
    parser.add_argument(
        "--api-initial-backoff",
        type=float,
        default=float(os.environ.get("CLAUDE_API_INITIAL_BACKOFF_SECONDS", "2.0")),
        help="Initial backoff (seconds) for API retries.",
    )
    parser.add_argument(
        "--api-max-backoff",
        type=float,
        default=float(os.environ.get("CLAUDE_API_MAX_BACKOFF_SECONDS", "30.0")),
        help="Maximum backoff (seconds) for API retries.",
    )
    args = parser.parse_args()

    input_path = Path(args.input).resolve()
    if not input_path.is_file():
        raise FileNotFoundError(
            f"Markdown spec not found: {input_path}\n"
            "Pass --input with a valid path, or ensure graph/spec/graph_specification.md exists."
        )
    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    api_key = os.environ.get("ANTHROPIC_API_KEY") or os.environ.get("CLAUDE_API_KEY")
    if not api_key:
        raise RuntimeError(
            "Missing API key. Set ANTHROPIC_API_KEY (recommended) or CLAUDE_API_KEY in your environment."
        )

    spec_md = read_text(input_path)

    client = Anthropic(api_key=api_key)

    system_prompt = (
        "You are an expert Neo4j engineer. Given a graph design specification in Markdown, "
        "infer a practical Neo4j schema and produce a simple, consistent implementation closely matching the design.\n\n"
        "Output requirements:\n"
        "1) A short summary of the interpreted graph model.\n"
        "2) A proposed Neo4j schema design.\n"
        "3) Cypher statements to create constraints and indexes.\n"
        "4) Cypher examples to create sample nodes and relationships.\n"
        "5) Cypher queries to validate that the graph was created correctly.\n"
        "6) If ambiguous, explicitly state ambiguity and make the most reasonable assumption.\n"
        "Return the result in this structure inside the Markdown document:\n"
        "## 1. Interpreted graph design\n"
        "## 2. Neo4j schema mapping\n"
        "## 3. Constraints and indexes (Cypher)\n"
        "## 4. Sample data load (Cypher)\n"
        "## 5. Validation queries (Cypher)\n"
        "## 6. Assumptions and ambiguities\n\n"
        "Cypher rules:\n"
        "- Use Neo4j labels for node types.\n"
        "- Use uppercase names for relationship types.\n"
        "- Prefer MERGE for entities with stable identifiers.\n"
        "- Add uniqueness constraints for primary IDs where appropriate.\n"
        "- Model Statement as per-utterance instance nodes.\n"
        "- Never enforce uniqueness on Statement.text.\n"
        "- If Statement uniqueness is needed, use Statement.statementId.\n"
        "- Do not invent extra node or relationship types unless necessary.\n"
        "- Keep it simple and close to the provided design."
    )

    user_prompt = f"""
Graph design specification (Markdown):

{spec_md}

Now produce EXACTLY two blocks with these markers:

{NEO4J_CYPHER_MARKER_START}
PASTE ONLY the full Cypher here:
- constraints + indexes
- sample data load
- (optionally) validation queries at the bottom as commented blocks
{NEO4J_CYPHER_MARKER_END}

{MD_MARKER_START}
PASTE ONLY the implementation explanation Markdown with the required sections:
## 1. Interpreted graph design
## 2. Neo4j schema mapping
## 3. Constraints and indexes (Cypher)
## 4. Sample data load (Cypher)
## 5. Validation queries (Cypher)
## 6. Assumptions and ambiguities
{MD_MARKER_END}
"""

    msg = create_message_with_retries(
        client,
        model=args.model,
        max_tokens=args.max_tokens,
        temperature=args.temperature,
        system=system_prompt,
        messages=[{"role": "user", "content": user_prompt}],
        max_attempts=max(1, args.api_retries),
        initial_backoff_seconds=max(0.1, args.api_initial_backoff),
        max_backoff_seconds=max(0.1, args.api_max_backoff),
    )

    content = message_to_text(msg)
    cypher = extract_block_flexible(content, NEO4J_CYPHER_MARKER_START, NEO4J_CYPHER_MARKER_END)
    impl_md = extract_block_flexible(content, MD_MARKER_START, MD_MARKER_END)

    if not cypher:
        cypher = extract_cypher_fallback(content)
    if not impl_md:
        impl_md = extract_md_by_sections(content)
    if not impl_md and content:
        impl_md = build_impl_md_fallback(content, cypher)

    timestamp_prefix = datetime.now().strftime("%Y%m%d_%H%M")

    if not cypher:
        raw_out = output_dir / f"{timestamp_prefix}_claude_raw_response.md"
        raw_out.write_text(content + "\n", encoding="utf-8")
        raise RuntimeError(
            "Could not extract a Cypher block from model output. "
            f"Raw response saved to: {raw_out}. "
            "Try again or lower temperature."
        )

    cypher = normalize_statement_instance_model(cypher)
    cypher_out = output_dir / f"{timestamp_prefix}_neo4j_implementation.cypher"
    md_out = output_dir / f"{timestamp_prefix}_NEO4J_SCHEMA.md"

    cypher_out.write_text(cypher, encoding="utf-8")
    md_out.write_text(impl_md + "\n", encoding="utf-8")

    print(f"Wrote: {cypher_out}")
    print(f"Wrote: {md_out}")


if __name__ == "__main__":
    main()