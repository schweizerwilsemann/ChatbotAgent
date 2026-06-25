"""
Step 01b: Scrape additional sports data from Wikipedia and official sources.

Fetches supplementary rules/techniques data to expand the knowledge graph.

Usage:
    cd backend
    python -m data_pipeline.01b_scrape_extra
"""

import asyncio
import json
import logging
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import httpx
from bs4 import BeautifulSoup

logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger(__name__)

RAW_DATA_DIR = Path(__file__).resolve().parent / "raw_data"

# Wikipedia pages to scrape for each sport
WIKI_SOURCES = {
    "badminton": [
        {
            "url": "https://en.wikipedia.org/wiki/Badminton",
            "title": "Badminton - Wikipedia",
            "sections": ["Rules", "Scoring", "Service", "Court", "Equipment"],
        },
        {
            "url": "https://en.wikipedia.org/wiki/Glossary_of_badminton_terms",
            "title": "Badminton Glossary",
            "sections": [],
        },
    ],
    "pickleball": [
        {
            "url": "https://en.wikipedia.org/wiki/Pickleball",
            "title": "Pickleball - Wikipedia",
            "sections": ["Rules", "Play", "Scoring", "Court", "Equipment"],
        },
        {
            "url": "https://en.wikipedia.org/wiki/Glossary_of_pickleball_terms",
            "title": "Pickleball Glossary",
            "sections": [],
        },
    ],
    "billiards": [
        {
            "url": "https://en.wikipedia.org/wiki/Billiards",
            "title": "Billiards - Wikipedia",
            "sections": ["Rules", "Equipment", "Techniques"],
        },
        {
            "url": "https://en.wikipedia.org/wiki/Glossary_of_cue_sports_terms",
            "title": "Billiards Glossary",
            "sections": [],
        },
        {
            "url": "https://en.wikipedia.org/wiki/Three-cushion_billiards",
            "title": "Three-cushion billiards",
            "sections": ["Rules", "Technique"],
        },
    ],
}

# Additional technique pages
TECHNIQUE_SOURCES = {
    "badminton": [
        "https://en.wikipedia.org/wiki/Clear_(badminton)",
        "https://en.wikipedia.org/wiki/Smash_(badminton)",
        "https://en.wikipedia.org/wiki/Drop_shot_(badminton)",
        "https://en.wikipedia.org/wiki/Net_shot_(badminton)",
        "https://en.wikipedia.org/wiki/Drive_(badminton)",
    ],
    "pickleball": [
        "https://en.wikipedia.org/wiki/Dink_(pickleball)",
        "https://en.wikipedia.org/wiki/Third_shot_drop",
    ],
}


async def fetch_page(client: httpx.AsyncClient, url: str) -> str | None:
    """Fetch a web page and return its HTML."""
    try:
        resp = await client.get(url, follow_redirects=True, timeout=15.0)
        if resp.status_code == 200:
            return resp.text
        logger.warning("  HTTP %d for %s", resp.status_code, url)
        return None
    except Exception as exc:
        logger.warning("  Failed to fetch %s: %s", url, exc)
        return None


def extract_text_from_html(html: str, sections: list[str] = None) -> str:
    """Extract readable text from HTML, optionally filtering to specific sections."""
    soup = BeautifulSoup(html, "html.parser")
    
    # Remove script, style, nav, footer
    for tag in soup(["script", "style", "nav", "footer", "header", "aside"]):
        tag.decompose()
    
    # Try to find the main content (Wikipedia-specific)
    content = soup.find("div", {"id": "mw-content-text"})
    if not content:
        content = soup.find("article") or soup.find("main") or soup
    
    # If specific sections requested, extract only those
    if sections:
        section_texts = []
        for heading in content.find_all(["h2", "h3"]):
            heading_text = heading.get_text(strip=True).lower()
            if any(s.lower() in heading_text for s in sections):
                # Get text until next heading
                texts = []
                for sibling in heading.find_next_siblings():
                    if sibling.name in ["h2", "h3"]:
                        break
                    text = sibling.get_text(strip=True)
                    if text:
                        texts.append(text)
                if texts:
                    section_texts.append(f"[SECTION: {heading.get_text(strip=True)}]")
                    section_texts.extend(texts)
        if section_texts:
            return "\n".join(section_texts)
    
    # Fallback: extract all paragraph text
    paragraphs = []
    for p in content.find_all("p"):
        text = p.get_text(strip=True)
        if len(text) > 30:  # Skip short fragments
            paragraphs.append(text)
    
    return "\n\n".join(paragraphs)


def extract_glossary(html: str) -> list[dict]:
    """Extract glossary terms from a Wikipedia glossary page."""
    soup = BeautifulSoup(html, "html.parser")
    content = soup.find("div", {"id": "mw-content-text"})
    if not content:
        return []
    
    terms = []
    # Look for definition lists
    for dl in content.find_all("dl"):
        for dt in dl.find_all("dt"):
            term = dt.get_text(strip=True)
            dd = dt.find_next_sibling("dd")
            definition = dd.get_text(strip=True) if dd else ""
            if term and definition and len(definition) > 20:
                terms.append({"term": term, "definition": definition})
    
    # Also look for bold terms followed by descriptions
    for p in content.find_all("p"):
        bold = p.find("b")
        if bold:
            term = bold.get_text(strip=True)
            rest = p.get_text(strip=True).replace(term, "").strip()
            if term and rest and len(rest) > 20:
                terms.append({"term": term, "definition": rest[:500]})
    
    return terms


async def main():
    logger.info("=" * 60)
    logger.info("Scraping additional sports data from Wikipedia")
    logger.info("=" * 60)
    
    async with httpx.AsyncClient(
        headers={"User-Agent": "SportsVenueChatbot/1.0 (educational project)"}
    ) as client:
        
        for sport, sources in WIKI_SOURCES.items():
            sport_dir = RAW_DATA_DIR / sport
            sport_dir.mkdir(parents=True, exist_ok=True)
            
            all_text = []
            
            for source in sources:
                url = source["url"]
                title = source["title"]
                sections = source.get("sections", [])
                
                logger.info("Fetching: %s", title)
                html = await fetch_page(client, url)
                if not html:
                    continue
                
                # Check if it's a glossary page
                if "glossary" in url.lower() or "terms" in url.lower():
                    terms = extract_glossary(html)
                    if terms:
                        text_parts = [f"[TOPIC: {title}]"]
                        for t in terms[:100]:  # Limit to 100 terms
                            text_parts.append(f"{t['term']}: {t['definition']}")
                        text = "\n".join(text_parts)
                        all_text.append(text)
                        logger.info("  Extracted %d glossary terms", len(terms))
                else:
                    text = extract_text_from_html(html, sections)
                    if text and len(text) > 100:
                        all_text.append(f"[TOPIC: {title}]\n{text}")
                        logger.info("  Extracted %d chars", len(text))
                
                await asyncio.sleep(1)  # Rate limiting
            
            # Also fetch technique-specific pages
            for url in TECHNIQUE_SOURCES.get(sport, []):
                logger.info("Fetching: %s", url.split("/")[-1])
                html = await fetch_page(client, url)
                if html:
                    text = extract_text_from_html(html)
                    if text and len(text) > 100:
                        title = url.split("/")[-1].replace("_", " ")
                        all_text.append(f"[TOPIC: {title}]\n{text}")
                        logger.info("  Extracted %d chars", len(text))
                await asyncio.sleep(1)
            
            # Save combined text
            if all_text:
                combined = "\n\n---\n\n".join(all_text)
                output_file = sport_dir / "wikipedia_extra.txt"
                output_file.write_text(combined, encoding="utf-8")
                logger.info("Saved %d chars to %s", len(combined), output_file)
    
    logger.info("\nDone! Run 02_extract_entities.py to process the new data.")


if __name__ == "__main__":
    asyncio.run(main())
