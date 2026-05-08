"""
WPA (World Pool-Billiard Association) Scraper.

Scrapes billiards rules from wpapool.com and returns structured data
for knowledge graph construction.
"""

import logging
import re

from bs4 import BeautifulSoup, Tag

from .base_scraper import BaseScraper

logger = logging.getLogger(__name__)

WPA_RULES_URLS = [
    "https://wpapool.com/rules/",
    "https://wpapool.com/rules-of-play/",
    "https://wpapool.com/standardized-rules/",
]


class WPAScraper(BaseScraper):
    """Scraper for WPA billiards rules from wpapool.com."""

    def __init__(self, **kwargs) -> None:
        """Initialize the WPA scraper."""
        super().__init__(**kwargs)

    def parse(self, html: str) -> list[dict]:
        """
        Parse WPA rules page HTML and extract rule sections.

        Args:
            html: The raw HTML content from wpapool.com.

        Returns:
            A list of dicts with 'title', 'content', and 'sport' keys.
        """
        if not html or not html.strip():
            logger.warning("Empty HTML provided to WPA parser")
            return []

        try:
            soup = BeautifulSoup(html, "html.parser")
        except Exception as exc:
            logger.error("Failed to parse WPA HTML: %s", exc)
            return []

        rules: list[dict] = []

        # Remove navigation, header, footer, scripts, styles
        for tag_name in ("nav", "header", "footer", "script", "style", "noscript"):
            for tag in soup.find_all(tag_name):
                tag.decompose()

        # Strategy 1: Look for headings (h1-h4) as rule section headers
        headings = soup.find_all(re.compile(r"^h[1-4]$"))
        if headings:
            for i, heading in enumerate(headings):
                title = heading.get_text(strip=True)
                if not title or len(title) < 3:
                    continue

                # Collect content between this heading and the next heading
                content_parts: list[str] = []
                sibling = heading.find_next_sibling()
                next_heading = headings[i + 1] if i + 1 < len(headings) else None

                while sibling and sibling != next_heading:
                    if sibling.name and sibling.name.startswith("h"):
                        break
                    text = sibling.get_text(separator=" ", strip=True)
                    if text and len(text) > 5:
                        content_parts.append(text)
                    sibling = sibling.find_next_sibling()

                content = " ".join(content_parts)
                if content and len(content) > 20:
                    # Clean up the content
                    content = re.sub(r"\s+", " ", content).strip()
                    rules.append(
                        {
                            "title": title,
                            "content": content,
                            "sport": "billiards",
                            "source": "wpapool.com",
                        }
                    )

        # Strategy 2: Look for content sections, article bodies, or div containers
        if len(rules) < 3:
            content_sections = soup.find_all(
                ["div", "article", "section"],
                class_=re.compile(
                    r"(content|article|post|entry|rule|body|main)", re.IGNORECASE
                ),
            )

            for section in content_sections:
                if not isinstance(section, Tag):
                    continue

                # Try to find a title within the section
                title_tag = section.find(re.compile(r"^h[1-4]$"))
                title = ""
                if title_tag:
                    title = title_tag.get_text(strip=True)

                # Get the section text
                paragraphs = section.find_all("p")
                if paragraphs:
                    content = " ".join(
                        p.get_text(separator=" ", strip=True)
                        for p in paragraphs
                        if p.get_text(strip=True)
                    )
                else:
                    content = section.get_text(separator=" ", strip=True)

                if not title and content:
                    # Generate a title from the first sentence
                    first_sentence = re.split(r"[.!?]", content)[0][:100]
                    title = first_sentence.strip()

                content = re.sub(r"\s+", " ", content).strip()

                if content and len(content) > 30:
                    # Check if this content is not already captured
                    is_duplicate = any(
                        content[:100] in existing["content"][:100] for existing in rules
                    )
                    if not is_duplicate:
                        rules.append(
                            {
                                "title": title or "WPA Rule",
                                "content": content,
                                "sport": "billiards",
                                "source": "wpapool.com",
                            }
                        )

        # Strategy 3: Fallback — extract all meaningful paragraphs
        if not rules:
            paragraphs = soup.find_all("p")
            for p in paragraphs:
                text = p.get_text(separator=" ", strip=True)
                if text and len(text) > 50:
                    rules.append(
                        {
                            "title": "WPA Rule",
                            "content": re.sub(r"\s+", " ", text).strip(),
                            "sport": "billiards",
                            "source": "wpapool.com",
                        }
                    )

        logger.info("Parsed %d rule sections from WPA page", len(rules))
        return rules

    async def scrape_all(self) -> list[dict]:
        """
        Scrape rules from all known WPA URLs.

        Returns:
            A combined list of all parsed rule dicts.
        """
        all_rules: list[dict] = []
        seen_contents: set[str] = set()

        for url in WPA_RULES_URLS:
            try:
                rules = await self.scrape(url)
                for rule in rules:
                    # Deduplicate by content fingerprint
                    fingerprint = rule["content"][:200].lower()
                    if fingerprint not in seen_contents:
                        seen_contents.add(fingerprint)
                        all_rules.append(rule)
            except Exception as exc:
                logger.error("Failed to scrape WPA URL %s: %s", url, exc)

        logger.info("Total WPA rules scraped: %d", len(all_rules))
        return all_rules
