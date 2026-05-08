"""
Master Pipeline Script.

Runs all 4 data pipeline steps in sequence:
1. Scrape raw data from sports sources
2. Extract entities and relationships via LLM
3. Build Neo4j knowledge graph
4. Generate and store node embeddings

Includes comprehensive logging and error handling.
"""

import asyncio
import logging
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(
            Path(__file__).resolve().parent / "pipeline.log",
            mode="a",
            encoding="utf-8",
        ),
    ],
)
logger = logging.getLogger(__name__)


def log_step_header(step_num: int, step_name: str) -> None:
    """Log a formatted step header."""
    logger.info("=" * 60)
    logger.info("STEP %d: %s", step_num, step_name)
    logger.info("=" * 60)


def log_step_result(
    step_num: int, step_name: str, success: bool, elapsed: float
) -> None:
    """Log a formatted step result."""
    status = "SUCCESS" if success else "FAILED"
    logger.info("-" * 60)
    logger.info("STEP %d %s: %s (%.1f seconds)", step_num, status, step_name, elapsed)
    logger.info("-" * 60)


async def run_step_1_scrape(include_youtube: bool = False) -> bool:
    """
    Step 1: Run all scrapers to collect raw data.

    Args:
        include_youtube: Whether to include YouTube scraping.

    Returns:
        True if scraping completed successfully, False otherwise.
    """
    log_step_header(1, "Scrape Raw Data")

    try:
        import importlib.util

        spec = importlib.util.spec_from_file_location(
            "step_01_scrape",
            Path(__file__).resolve().parent / "01_scrape.py",
        )
        if spec is None or spec.loader is None:
            logger.error("Could not load step 01_scrape module")
            return False
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        await module.main(include_youtube=include_youtube)
        return True

    except Exception as exc:
        logger.error("Step 1 (Scrape) failed: %s", exc)
        return False


async def run_step_2_extract() -> bool:
    """
    Step 2: Extract entities from raw data.

    Returns:
        True if extraction completed successfully, False otherwise.
    """
    log_step_header(2, "Extract Entities")

    try:
        import importlib.util

        spec = importlib.util.spec_from_file_location(
            "step_02_extract",
            Path(__file__).resolve().parent / "02_extract_entities.py",
        )
        if spec is None or spec.loader is None:
            logger.error("Could not load step 02_extract_entities module")
            return False
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        await module.main()
        return True

    except Exception as exc:
        logger.error("Step 2 (Extract) failed: %s", exc)
        return False


async def run_step_3_build_graph() -> bool:
    """
    Step 3: Build the Neo4j knowledge graph.

    Returns:
        True if graph building completed successfully, False otherwise.
    """
    log_step_header(3, "Build Knowledge Graph")

    try:
        import importlib.util

        spec = importlib.util.spec_from_file_location(
            "step_03_build",
            Path(__file__).resolve().parent / "03_build_graph.py",
        )
        if spec is None or spec.loader is None:
            logger.error("Could not load step 03_build_graph module")
            return False
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        await module.main()
        return True

    except Exception as exc:
        logger.error("Step 3 (Build Graph) failed: %s", exc)
        return False


async def run_step_4_embed() -> bool:
    """
    Step 4: Generate and store node embeddings.

    Returns:
        True if embedding completed successfully, False otherwise.
    """
    log_step_header(4, "Generate Embeddings")

    try:
        import importlib.util

        spec = importlib.util.spec_from_file_location(
            "step_04_embed",
            Path(__file__).resolve().parent / "04_embed_nodes.py",
        )
        if spec is None or spec.loader is None:
            logger.error("Could not load step 04_embed_nodes module")
            return False
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        await module.main()
        return True

    except Exception as exc:
        logger.error("Step 4 (Embed) failed: %s", exc)
        return False


async def run_full_pipeline(
    include_youtube: bool = False, skip_steps: list[int] | None = None
) -> None:
    """
    Run the full data pipeline from scraping to embedding.

    Args:
        include_youtube: Whether to include YouTube scraping in Step 1.
        skip_steps: List of step numbers to skip (1-4).
    """
    skip_steps = skip_steps or []
    pipeline_start = time.time()

    logger.info("=" * 60)
    logger.info("SPORTS VENUE AI CHATBOT - KNOWLEDGE GRAPH PIPELINE")
    logger.info("Started at: %s", datetime.now(timezone.utc).isoformat())
    logger.info("Skip steps: %s", skip_steps if skip_steps else "none")
    logger.info("=" * 60)

    steps = [
        (1, "Scrape Raw Data", run_step_1_scrape, {"include_youtube": include_youtube}),
        (2, "Extract Entities", run_step_2_extract, {}),
        (3, "Build Knowledge Graph", run_step_3_build_graph, {}),
        (4, "Generate Embeddings", run_step_4_embed, {}),
    ]

    results = {}

    for step_num, step_name, step_func, kwargs in steps:
        if step_num in skip_steps:
            logger.info("Skipping Step %d: %s", step_num, step_name)
            results[step_num] = "skipped"
            continue

        step_start = time.time()
        try:
            success = await step_func(**kwargs)
            elapsed = time.time() - step_start
            log_step_result(step_num, step_name, success, elapsed)
            results[step_num] = "success" if success else "failed"

            # If a step fails, check if we should continue
            if not success:
                if step_num in (1, 2):
                    logger.warning(
                        "Step %d failed but continuing to next step "
                        "(may use previously generated data)",
                        step_num,
                    )
                elif step_num == 3:
                    logger.error(
                        "Step 3 (Build Graph) failed. Step 4 (Embed) "
                        "requires Neo4j data. Consider skipping step 4."
                    )

        except Exception as exc:
            elapsed = time.time() - step_start
            logger.error("Step %d crashed: %s", step_num, exc)
            log_step_result(step_num, step_name, False, elapsed)
            results[step_num] = "crashed"

    # Final summary
    total_elapsed = time.time() - pipeline_start

    logger.info("")
    logger.info("=" * 60)
    logger.info("PIPELINE SUMMARY")
    logger.info("=" * 60)

    for step_num, step_name, _, _ in steps:
        status = results.get(step_num, "not_run")
        icon = {"success": "✓", "failed": "✗", "crashed": "✗", "skipped": "○"}.get(
            status, "?"
        )
        logger.info("  Step %d [%s] %s: %s", step_num, icon, step_name, status)

    logger.info("-" * 60)
    logger.info("Total elapsed time: %.1f seconds", total_elapsed)

    success_count = sum(1 for s in results.values() if s == "success")
    total_steps = len(steps) - len(skip_steps)
    logger.info("Steps completed: %d/%d", success_count, total_steps)

    if success_count == total_steps:
        logger.info("Pipeline completed successfully!")
    else:
        logger.warning("Pipeline completed with some failures. Check logs for details.")

    logger.info("=" * 60)


def main() -> None:
    """Parse arguments and run the pipeline."""
    include_youtube = "--youtube" in sys.argv
    skip_steps: list[int] = []

    for arg in sys.argv:
        if arg.startswith("--skip="):
            try:
                steps_str = arg.split("=")[1]
                skip_steps = [int(s) for s in steps_str.split(",")]
            except (ValueError, IndexError):
                logger.warning("Invalid --skip argument: %s", arg)

    if "--help" in sys.argv or "-h" in sys.argv:
        print("Sports Venue AI Chatbot - Knowledge Graph Pipeline")
        print()
        print("Usage: python run_pipeline.py [options]")
        print()
        print("Options:")
        print("  --youtube       Include YouTube technique video scraping")
        print("  --skip=1,2,3    Skip specific pipeline steps (comma-separated)")
        print("  --help, -h      Show this help message")
        print()
        print("Steps:")
        print("  1. Scrape raw data from sports sources")
        print("  2. Extract entities and relationships via LLM")
        print("  3. Build Neo4j knowledge graph")
        print("  4. Generate and store node embeddings")
        return

    asyncio.run(
        run_full_pipeline(include_youtube=include_youtube, skip_steps=skip_steps)
    )


if __name__ == "__main__":
    main()
