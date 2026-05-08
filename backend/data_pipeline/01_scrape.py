"""
Step 01: Scrape raw data from sports sources.

Runs all scrapers (WPA billiards, BWF badminton, USA Pickleball rules)
and optionally YouTube technique videos. Saves results to JSON files
in the raw_data/ directory with metadata.
"""

import asyncio
import json
import logging
import sys
from datetime import datetime, timezone
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.kg.scraper.bwf_scraper import BWFScraper
from app.kg.scraper.pickleball_scraper import PickleballScraper
from app.kg.scraper.wpa_scraper import WPAScraper
from app.kg.scraper.youtube_scraper import YouTubeScraper

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

RAW_DATA_DIR = Path(__file__).resolve().parent / "raw_data"


def save_to_json(data: list[dict], filename: str, metadata: dict) -> Path:
    """
    Save scraped data to a JSON file with metadata.

    Args:
        data: List of scraped data dicts.
        filename: Name of the output JSON file.
        metadata: Metadata dict with source, timestamp, sport info.

    Returns:
        Path to the saved JSON file.
    """
    RAW_DATA_DIR.mkdir(parents=True, exist_ok=True)

    output = {
        "metadata": metadata,
        "scraped_at": datetime.now(timezone.utc).isoformat(),
        "item_count": len(data),
        "data": data,
    }

    filepath = RAW_DATA_DIR / filename
    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    logger.info("Saved %d items to %s", len(data), filepath)
    return filepath


async def scrape_wpa_rules() -> list[dict]:
    """Scrape billiards rules from WPA."""
    logger.info("=== Scraping WPA billiards rules ===")
    scraper = WPAScraper(max_retries=3, rate_limit_delay=2.0)
    try:
        rules = await scraper.scrape_all()
        if rules:
            save_to_json(
                rules,
                "wpa_billiards_rules.json",
                metadata={
                    "source": "wpapool.com",
                    "sport": "billiards",
                    "type": "rules",
                    "scraper": "WPAScraper",
                },
            )
        return rules
    except Exception as exc:
        logger.error("WPA scraping failed: %s", exc)
        return []


async def scrape_bwf_rules() -> list[dict]:
    """Scrape badminton rules from BWF."""
    logger.info("=== Scraping BWF badminton rules ===")
    scraper = BWFScraper(max_retries=3, rate_limit_delay=2.0)
    try:
        rules = await scraper.scrape_all()
        if rules:
            save_to_json(
                rules,
                "bwf_badminton_rules.json",
                metadata={
                    "source": "bwfbadminton.com",
                    "sport": "badminton",
                    "type": "rules",
                    "scraper": "BWFScraper",
                },
            )
        return rules
    except Exception as exc:
        logger.error("BWF scraping failed: %s", exc)
        return []


async def scrape_pickleball_rules() -> list[dict]:
    """Scrape pickleball rules from USA Pickleball."""
    logger.info("=== Scraping USA Pickleball rules ===")
    scraper = PickleballScraper(max_retries=3, rate_limit_delay=2.0)
    try:
        rules = await scraper.scrape_all()
        if rules:
            save_to_json(
                rules,
                "usa_pickleball_rules.json",
                metadata={
                    "source": "usapickleball.org",
                    "sport": "pickleball",
                    "type": "rules",
                    "scraper": "PickleballScraper",
                },
            )
        return rules
    except Exception as exc:
        logger.error("Pickleball scraping failed: %s", exc)
        return []


async def scrape_youtube_techniques(include_youtube: bool = False) -> list[dict]:
    """
    Optionally scrape YouTube technique videos for all sports.

    Args:
        include_youtube: Whether to include YouTube scraping (disabled by default
                         since it requires yt-dlp and is slow).

    Returns:
        List of scraped YouTube transcript dicts.
    """
    if not include_youtube:
        logger.info("=== YouTube scraping skipped (use --youtube flag to enable) ===")
        return []

    logger.info("=== Scraping YouTube technique videos ===")
    scraper = YouTubeScraper(max_retries=2, rate_limit_delay=3.0)
    all_transcripts: list[dict] = []

    for sport in ["billiards", "pickleball", "badminton"]:
        logger.info("Scraping YouTube videos for sport: %s", sport)
        try:
            transcripts = await scraper.scrape_sport_techniques(
                sport, max_videos_per_query=2
            )
            all_transcripts.extend(transcripts)

            if transcripts:
                save_to_json(
                    transcripts,
                    f"youtube_{sport}_techniques.json",
                    metadata={
                        "source": "youtube.com",
                        "sport": sport,
                        "type": "techniques",
                        "scraper": "YouTubeScraper",
                    },
                )
        except Exception as exc:
            logger.error("YouTube scraping failed for %s: %s", sport, exc)

    return all_transcripts


async def main(include_youtube: bool = False) -> None:
    """
    Run all scrapers and save results.

    Args:
        include_youtube: Whether to include YouTube scraping.
    """
    logger.info("Starting data scraping pipeline")
    logger.info("Output directory: %s", RAW_DATA_DIR)

    # Run all scrapers (concurrent where possible)
    wpa_task = scrape_wpa_rules()
    bwf_task = scrape_bwf_rules()
    pb_task = scrape_pickleball_rules()

    wpa_rules, bwf_rules, pb_rules = await asyncio.gather(
        wpa_task, bwf_task, pb_task, return_exceptions=True
    )

    # Handle results
    total_items = 0
    if isinstance(wpa_rules, list):
        total_items += len(wpa_rules)
        logger.info("WPA billiards rules: %d items", len(wpa_rules))
    else:
        logger.error("WPA scraping raised: %s", wpa_rules)

    if isinstance(bwf_rules, list):
        total_items += len(bwf_rules)
        logger.info("BWF badminton rules: %d items", len(bwf_rules))
    else:
        logger.error("BWF scraping raised: %s", bwf_rules)

    if isinstance(pb_rules, list):
        total_items += len(pb_rules)
        logger.info("USA Pickleball rules: %d items", len(pb_rules))
    else:
        logger.error("Pickleball scraping raised: %s", pb_rules)

    # YouTube is optional and slow
    if include_youtube:
        yt_results = await scrape_youtube_techniques(include_youtube=True)
        total_items += len(yt_results)
        logger.info("YouTube technique transcripts: %d items", len(yt_results))

    logger.info("Scraping complete. Total items collected: %d", total_items)


if __name__ == "__main__":
    youtube_flag = "--youtube" in sys.argv
    asyncio.run(main(include_youtube=youtube_flag))
