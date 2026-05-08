"""
Step 02: Extract entities and relationships from raw text data.

Reads .txt files from raw_data/ (organized by sport subdirectories), parses
them into chunks using [SECTION:] and [TOPIC:] headers, sends each chunk to
an LLM for entity/relationship extraction, and saves results to the
extracted/ directory as JSON.

Supports PDF pre-processing: any .pdf files found in raw_data/ are converted
to .txt using pdfplumber before extraction begins.

LLM priority: Gemini > OpenAI > Ollama (no mock fallback).

Usage:
    cd backend
    python -m data_pipeline.02_extract_entities
"""

import asyncio
import json
import logging
import os
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from dotenv import load_dotenv

# Load .env before any other imports that read environment variables
load_dotenv(Path(__file__).resolve().parent.parent / ".env")

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.kg.builder import KnowledgeGraphBuilder

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

RAW_DATA_DIR = Path(__file__).resolve().parent / "raw_data"
EXTRACTED_DIR = Path(__file__).resolve().parent / "extracted"

# Rate limiting configuration
LLM_RATE_LIMIT_DELAY = 5.0  # seconds between LLM calls
LLM_MAX_CONCURRENT = 1  # max concurrent LLM calls

# Known sport directory names (used to infer sport from path)
KNOWN_SPORTS = {"billiards", "pickleball", "badminton", "venue"}


# ---------------------------------------------------------------------------
# PDF pre-processing
# ---------------------------------------------------------------------------


def process_pdf_files() -> int:
    """
    Find all .pdf files in raw_data/ subdirectories, extract their text
    using pdfplumber, and save as .txt files in the same directory.

    Skips conversion if a .txt file with the same stem already exists.

    Returns:
        Number of PDF files converted.
    """
    pdf_files = sorted(RAW_DATA_DIR.rglob("*.pdf"))
    if not pdf_files:
        logger.info("No PDF files found in %s", RAW_DATA_DIR)
        return 0

    try:
        import pdfplumber
    except ImportError:
        logger.error(
            "pdfplumber is not installed. Install it with: pip install pdfplumber"
        )
        return 0

    converted = 0
    for pdf_path in pdf_files:
        txt_path = pdf_path.with_suffix(".txt")

        # Skip if .txt already exists (already converted)
        if txt_path.exists():
            logger.info("Skipping PDF (txt already exists): %s", pdf_path.name)
            continue

        logger.info("Extracting text from PDF: %s", pdf_path.name)
        try:
            pages_text: list[str] = []
            with pdfplumber.open(pdf_path) as pdf:
                for i, page in enumerate(pdf.pages):
                    text = page.extract_text()
                    if text:
                        pages_text.append(text)

            if not pages_text:
                logger.warning("No text extracted from PDF: %s", pdf_path.name)
                continue

            full_text = "\n\n".join(pages_text)
            txt_path.write_text(full_text, encoding="utf-8")
            logger.info(
                "Converted PDF to txt: %s (%d pages, %d chars)",
                pdf_path.name,
                len(pages_text),
                len(full_text),
            )
            converted += 1
        except Exception as exc:
            logger.error("Failed to process PDF %s: %s", pdf_path.name, exc)

    logger.info("PDF processing complete: %d/%d converted", converted, len(pdf_files))
    return converted


# ---------------------------------------------------------------------------
# File discovery
# ---------------------------------------------------------------------------


def load_raw_data_files() -> list[Path]:
    """
    Recursively discover all .txt files under raw_data/.

    Skips files whose name contains 'placeholder' or starts with 'local_rules'.

    Returns:
        Sorted list of Path objects for each qualifying .txt file.
    """
    if not RAW_DATA_DIR.exists():
        logger.error("Raw data directory does not exist: %s", RAW_DATA_DIR)
        return []

    all_txt = sorted(RAW_DATA_DIR.rglob("*.txt"))
    logger.info("Found %d total .txt files in %s", len(all_txt), RAW_DATA_DIR)

    filtered: list[Path] = []
    for p in all_txt:
        name_lower = p.name.lower()
        if "placeholder" in name_lower:
            logger.debug("Skipping placeholder file: %s", p.name)
            continue
        if name_lower.startswith("local_rules"):
            logger.debug("Skipping local_rules file: %s", p.name)
            continue
        if name_lower.startswith("scrape_report"):
            logger.debug("Skipping scrape report file: %s", p.name)
            continue
        filtered.append(p)

    logger.info("After filtering: %d .txt files to process", len(filtered))
    return filtered


# ---------------------------------------------------------------------------
# .txt file parsing
# ---------------------------------------------------------------------------

# Matches [SECTION: ...] or [TOPIC: ...] headers (case-insensitive, tolerant of
# extra whitespace and optional trailing ]).
_HEADER_RE = re.compile(
    r"^\[(?:SECTION|TOPIC)\s*:\s*(.+?)\s*\]?\s*$",
    re.IGNORECASE | re.MULTILINE,
)


def _infer_sport(filepath: Path) -> str:
    """
    Infer the sport name from the file's parent directory.

    Walks up from the file and checks if any parent directory name matches
    a known sport. Falls back to 'general'.
    """
    for ancestor in filepath.relative_to(RAW_DATA_DIR).parents:
        dir_name = ancestor.name.lower()
        if dir_name in KNOWN_SPORTS:
            return dir_name
    return "general"


def parse_txt_file(filepath: Path) -> list[dict]:
    """
    Parse a .txt file into content chunks based on [SECTION:] and [TOPIC:] headers.

    Each chunk contains:
      - text: the content between headers (stripped of leading/trailing whitespace)
      - title: the section/topic name from the header
      - sport: inferred from the directory path
      - source: the filename

    If the file has content before the first header, it is included as a chunk
    with the filename stem as the title.

    Args:
        filepath: Path to the .txt file.

    Returns:
        List of chunk dicts. Empty list if the file cannot be read or has
        no meaningful content.
    """
    try:
        raw_text = filepath.read_text(encoding="utf-8")
    except Exception as exc:
        logger.error("Failed to read %s: %s", filepath, exc)
        return []

    if not raw_text.strip():
        logger.warning("Empty file: %s", filepath)
        return []

    sport = _infer_sport(filepath)
    source = filepath.name

    # Find all header positions
    headers = list(_HEADER_RE.finditer(raw_text))
    if not headers:
        # No headers found — treat the entire file as a single chunk
        text = raw_text.strip()
        if len(text) > 20:
            return [
                {
                    "text": text,
                    "title": filepath.stem.replace("_", " ").title(),
                    "sport": sport,
                    "source": source,
                }
            ]
        logger.warning("No headers and too little content in %s", filepath)
        return []

    chunks: list[dict] = []

    # Content before the first header (if any)
    pre_header_text = raw_text[: headers[0].start()].strip()
    if pre_header_text and len(pre_header_text) > 20:
        chunks.append(
            {
                "text": pre_header_text,
                "title": filepath.stem.replace("_", " ").title(),
                "sport": sport,
                "source": source,
            }
        )

    # Content between consecutive headers
    for i, match in enumerate(headers):
        title = match.group(1).strip()
        start = match.end()
        end = headers[i + 1].start() if i + 1 < len(headers) else len(raw_text)
        text = raw_text[start:end].strip()

        # Remove leading/trailing separator lines (---) common in these files
        text = re.sub(r"^-{3,}\s*\n?", "", text, flags=re.MULTILINE)
        text = re.sub(r"\n?\s*-{3,}$", "", text, flags=re.MULTILINE)
        text = text.strip()

        if len(text) > 20:
            chunks.append(
                {
                    "text": text,
                    "title": title,
                    "sport": sport,
                    "source": source,
                }
            )

    logger.info("Parsed %s: %d chunks (sport=%s)", filepath.name, len(chunks), sport)
    return chunks


# ---------------------------------------------------------------------------
# LLM configuration
# ---------------------------------------------------------------------------


def _check_ollama_running(base_url: str) -> bool:
    """Check if Ollama is running and accessible."""
    import urllib.request

    try:
        req = urllib.request.Request(f"{base_url}/api/tags", method="GET")
        with urllib.request.urlopen(req, timeout=5) as resp:
            return resp.status == 200
    except Exception:
        return False


def get_llm():
    """
    Get an LLM instance for entity extraction.

    Priority order:
      1. Ollama (local, free, always preferred if running)
      2. Google Gemini (if GEMINI_API_KEY is set and quota available)
      3. OpenAI (if OPENAI_API_KEY is set)

    Raises:
        RuntimeError: If no LLM can be configured.

    Returns:
        A LangChain-compatible chat model instance.
    """
    # --- Ollama (local, free — preferred) ---
    ollama_base = os.environ.get("OLLAMA_BASE_URL", "http://localhost:11434")
    ollama_model = os.environ.get("OLLAMA_MODEL", "qwen2.5-coder:7b")

    if _check_ollama_running(ollama_base):
        try:
            from langchain_ollama import ChatOllama

            llm = ChatOllama(
                model=ollama_model,
                base_url=ollama_base,
                temperature=0.1,
                num_ctx=4096,
            )
            logger.info("Using Ollama LLM: %s (at %s)", ollama_model, ollama_base)
            return llm
        except ImportError:
            logger.warning(
                "langchain_ollama not installed. "
                "Install with: pip install langchain-ollama"
            )
    else:
        logger.info("Ollama not running at %s, trying other LLMs...", ollama_base)

    # --- Gemini ---
    gemini_key = os.environ.get("GEMINI_API_KEY", "")
    if gemini_key:
        try:
            from langchain_google_genai import ChatGoogleGenerativeAI

            llm = ChatGoogleGenerativeAI(
                model="gemini-2.0-flash",
                google_api_key=gemini_key,
                temperature=0.1,
                max_output_tokens=2000,
            )
            logger.info("Using Google Gemini LLM: gemini-2.0-flash")
            return llm
        except ImportError:
            logger.warning(
                "langchain_google_genai not installed. "
                "Install with: pip install langchain-google-genai"
            )

    # --- OpenAI (or compatible) ---
    openai_key = os.environ.get("OPENAI_API_KEY", "")
    openai_base = os.environ.get("OPENAI_API_BASE", "")
    llm_model = os.environ.get("LLM_MODEL", "gpt-4o-mini")

    if openai_key:
        try:
            from langchain_openai import ChatOpenAI

            kwargs = {
                "model": llm_model,
                "temperature": 0.1,
                "max_tokens": 2000,
                "openai_api_key": openai_key,
            }
            if openai_base:
                kwargs["openai_api_base"] = openai_base

            llm = ChatOpenAI(**kwargs)
            logger.info("Using OpenAI LLM: %s", llm_model)
            return llm
        except ImportError:
            logger.warning("langchain_openai not installed, trying alternatives...")

    # --- No LLM available ---
    raise RuntimeError(
        "No LLM configured. Set one of the following:\n"
        "  1. Start Ollama: ollama serve\n"
        "  2. Set GEMINI_API_KEY in .env\n"
        "  3. Set OPENAI_API_KEY in .env"
    )


# ---------------------------------------------------------------------------
# Entity extraction
# ---------------------------------------------------------------------------


async def extract_entities_from_chunks(
    builder: KnowledgeGraphBuilder,
    chunks: list[dict],
    semaphore: asyncio.Semaphore,
) -> list[dict]:
    """
    Extract entities from a list of parsed text chunks.

    Args:
        builder: The KnowledgeGraphBuilder instance.
        chunks: List of chunk dicts (from parse_txt_file).
        semaphore: Semaphore for rate limiting LLM calls.

    Returns:
        List of extraction result dicts with entities and relationships.
    """
    all_extractions: list[dict] = []

    for idx, chunk in enumerate(chunks):
        async with semaphore:
            try:
                entities_data = await builder.extract_entities(
                    text=chunk["text"],
                    source=chunk.get("source", "unknown"),
                    sport=chunk.get("sport", "general"),
                )

                if entities_data["entities"]:
                    all_extractions.append(
                        {
                            "chunk_title": chunk["title"],
                            "chunk_source": chunk["source"],
                            "sport": chunk.get("sport", "general"),
                            "extracted_at": datetime.now(timezone.utc).isoformat(),
                            "entity_count": len(entities_data["entities"]),
                            "relationship_count": len(entities_data["relationships"]),
                            "entities": entities_data["entities"],
                            "relationships": entities_data["relationships"],
                        }
                    )

                # Rate limiting between LLM calls
                await asyncio.sleep(LLM_RATE_LIMIT_DELAY)

            except Exception as exc:
                logger.error(
                    "Entity extraction failed for chunk '%s' (%s): %s",
                    chunk["title"],
                    chunk.get("source", "?"),
                    exc,
                )

        if (idx + 1) % 5 == 0 or idx + 1 == len(chunks):
            logger.info(
                "  Processed %d/%d chunks (%d extractions so far)",
                idx + 1,
                len(chunks),
                len(all_extractions),
            )

    return all_extractions


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------


def save_extracted_data(extractions: list[dict], source_name: str) -> Path:
    """
    Save extracted entities to a JSON file in the extracted/ directory.

    Args:
        extractions: List of extraction result dicts.
        source_name: Name of the source for the output filename.

    Returns:
        Path to the saved JSON file.
    """
    EXTRACTED_DIR.mkdir(parents=True, exist_ok=True)

    output = {
        "extracted_at": datetime.now(timezone.utc).isoformat(),
        "source": source_name,
        "extraction_count": len(extractions),
        "total_entities": sum(e.get("entity_count", 0) for e in extractions),
        "total_relationships": sum(e.get("relationship_count", 0) for e in extractions),
        "extractions": extractions,
    }

    # Sanitize filename
    safe_name = re.sub(r"[^\w\-.]", "_", source_name)
    filename = f"extracted_{safe_name}.json"
    filepath = EXTRACTED_DIR / filename

    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    logger.info(
        "Saved %d extractions (%d entities) to %s",
        len(extractions),
        output["total_entities"],
        filepath,
    )
    return filepath


# ---------------------------------------------------------------------------
# Main pipeline
# ---------------------------------------------------------------------------


async def main() -> None:
    """
    Run entity extraction on all raw data files.

    Pipeline:
      1. Process any PDF files in raw_data/ → save as .txt
      2. Discover all .txt files (excluding placeholders and local_rules)
      3. Parse each .txt file into chunks using [SECTION:]/[TOPIC:] headers
      4. For each chunk, call the LLM to extract entities
      5. Save extracted entities to extracted/ as JSON
    """
    logger.info("=" * 60)
    logger.info("Entity Extraction Pipeline")
    logger.info("=" * 60)
    logger.info("Raw data directory: %s", RAW_DATA_DIR)
    logger.info("Output directory:   %s", EXTRACTED_DIR)

    # Step 1: Convert any PDFs to .txt
    logger.info("--- Step 1: PDF pre-processing ---")
    process_pdf_files()

    # Step 2: Discover .txt files
    logger.info("--- Step 2: Discovering text files ---")
    txt_files = load_raw_data_files()
    if not txt_files:
        logger.error(
            "No .txt files found in %s. Run 01_scrape.py first or add data files.",
            RAW_DATA_DIR,
        )
        return

    # Step 3: Initialize LLM and builder
    logger.info("--- Step 3: Initializing LLM ---")
    llm = get_llm()
    builder = KnowledgeGraphBuilder(neo4j_client=None, llm=llm)

    # Step 4: Parse and extract
    logger.info("--- Step 4: Extracting entities ---")
    semaphore = asyncio.Semaphore(LLM_MAX_CONCURRENT)

    total_entities = 0
    total_relationships = 0
    total_chunks = 0
    files_processed = 0
    pipeline_start = time.time()

    for txt_file in txt_files:
        logger.info("Processing: %s", txt_file)

        chunks = parse_txt_file(txt_file)
        if not chunks:
            logger.info("  No parseable chunks, skipping.")
            continue

        total_chunks += len(chunks)
        file_start = time.time()

        extractions = await extract_entities_from_chunks(builder, chunks, semaphore)

        if extractions:
            # Build a descriptive source name from the relative path
            relative = txt_file.relative_to(RAW_DATA_DIR)
            source_name = (
                str(relative.with_suffix("")).replace("\\", "/").replace("/", "_")
            )

            save_extracted_data(extractions, source_name)

            file_entities = sum(e.get("entity_count", 0) for e in extractions)
            file_rels = sum(e.get("relationship_count", 0) for e in extractions)
            total_entities += file_entities
            total_relationships += file_rels

            elapsed = time.time() - file_start
            logger.info(
                "  Completed in %.1fs: %d chunks → %d entities, %d relationships",
                elapsed,
                len(chunks),
                file_entities,
                file_rels,
            )
        else:
            logger.info("  No entities extracted from %d chunks.", len(chunks))

        files_processed += 1

    # Summary
    elapsed_total = time.time() - pipeline_start
    logger.info("=" * 60)
    logger.info("Extraction complete!")
    logger.info("  Files processed:     %d / %d", files_processed, len(txt_files))
    logger.info("  Total chunks:        %d", total_chunks)
    logger.info("  Total entities:      %d", total_entities)
    logger.info("  Total relationships: %d", total_relationships)
    logger.info("  Elapsed time:        %.1fs", elapsed_total)
    logger.info("=" * 60)


if __name__ == "__main__":
    asyncio.run(main())
