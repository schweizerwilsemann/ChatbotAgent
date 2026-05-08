"""
BWF (Badminton World Federation) Scraper Module.

Scrapes badminton rules and laws from bwfbadminton.com
and returns structured data for knowledge graph construction.
"""

import logging
import re

from bs4 import BeautifulSoup, Tag

from .base_scraper import BaseScraper

logger = logging.getLogger(__name__)

BWF_RULES_URLS = [
    "https://bwfbadminton.com/rules/",
    "https://corporate.bwfbadminton.com/statutes/",
    "https://bwfbadminton.com/news/",
]


class BWFScraper(BaseScraper):
    """Scraper for BWF badminton rules from bwfbadminton.com."""

    def __init__(self, **kwargs) -> None:
        """Initialize the BWF scraper."""
        super().__init__(**kwargs)

    def parse(self, html: str) -> list[dict]:
        """
        Parse BWF rules page HTML and extract badminton law/rule sections.

        Args:
            html: The raw HTML content from bwfbadminton.com.

        Returns:
            A list of dicts with 'title', 'content', and 'sport' keys.
        """
        if not html or not html.strip():
            logger.warning("Empty HTML provided to BWF parser")
            return []

        try:
            soup = BeautifulSoup(html, "html.parser")
        except Exception as exc:
            logger.error("Failed to parse BWF HTML: %s", exc)
            return []

        rules: list[dict] = []

        # Remove non-content elements
        for tag_name in (
            "nav",
            "header",
            "footer",
            "script",
            "style",
            "noscript",
            "aside",
        ):
            for tag in soup.find_all(tag_name):
                tag.decompose()

        # Strategy 1: Extract by headings — badminton "Laws" are often structured with h2/h3
        headings = soup.find_all(re.compile(r"^h[1-4]$"))

        for i, heading in enumerate(headings):
            title = heading.get_text(strip=True)
            if not title or len(title) < 3:
                continue

            # Skip navigation-type headings
            if any(
                skip in title.lower()
                for skip in [
                    "menu",
                    "search",
                    "login",
                    "register",
                    "contact",
                    "about",
                    "privacy",
                    "terms",
                    "cookie",
                    "subscribe",
                    "newsletter",
                    "share",
                    "follow",
                    "social",
                ]
            ):
                continue

            # Collect content until next heading of same or higher level
            content_parts: list[str] = []
            sibling = heading.find_next_sibling()
            heading_level = int(heading.name[1])

            while sibling:
                if (
                    isinstance(sibling, Tag)
                    and sibling.name
                    and sibling.name.startswith("h")
                ):
                    sibling_level = int(sibling.name[1])
                    if sibling_level <= heading_level:
                        break
                text = sibling.get_text(separator=" ", strip=True)
                if text and len(text) > 5:
                    content_parts.append(text)
                sibling = sibling.find_next_sibling()

            content = " ".join(content_parts)
            if content and len(content) > 20:
                content = re.sub(r"\s+", " ", content).strip()
                rules.append(
                    {
                        "title": title,
                        "content": content,
                        "sport": "badminton",
                        "source": "bwfbadminton.com",
                    }
                )

        # Strategy 2: Look for law/section containers with structured HTML
        if len(rules) < 3:
            law_containers = soup.find_all(
                ["div", "section", "article"],
                class_=re.compile(
                    r"(law|rule|content|entry|post|article|body|section|accordion)",
                    re.IGNORECASE,
                ),
            )

            for container in law_containers:
                if not isinstance(container, Tag):
                    continue

                # Look for law numbers
                law_match = container.find(
                    string=re.compile(r"^(Law|Rule|Section)\s*\d+", re.IGNORECASE)
                )
                title = ""
                if law_match:
                    title = law_match.strip()
                else:
                    title_tag = container.find(re.compile(r"^h[1-5]$"))
                    if title_tag:
                        title = title_tag.get_text(strip=True)

                # Extract paragraphs
                paragraphs = container.find_all("p")
                if paragraphs:
                    content = " ".join(
                        p.get_text(separator=" ", strip=True)
                        for p in paragraphs
                        if p.get_text(strip=True)
                    )
                else:
                    content = container.get_text(separator=" ", strip=True)

                if not title and content:
                    first_sentence = re.split(r"[.!?]", content)[0][:100]
                    title = first_sentence.strip()

                content = re.sub(r"\s+", " ", content).strip()

                if content and len(content) > 30:
                    is_duplicate = any(
                        content[:100] in existing["content"][:100] for existing in rules
                    )
                    if not is_duplicate:
                        rules.append(
                            {
                                "title": title or "BWF Rule",
                                "content": content,
                                "sport": "badminton",
                                "source": "bwfbadminton.com",
                            }
                        )

        # Strategy 3: Extract ordered/unordered lists that look like rules
        if not rules:
            ordered_lists = soup.find_all("ol")
            for ol in ordered_lists:
                parent_heading = ol.find_previous(re.compile(r"^h[1-4]$"))
                title = parent_heading.get_text(strip=True) if parent_heading else ""

                list_items = ol.find_all("li")
                if len(list_items) < 2:
                    continue

                items_text = []
                for li in list_items:
                    text = li.get_text(separator=" ", strip=True)
                    if text and len(text) > 5:
                        items_text.append(text)

                if items_text:
                    content = " ".join(items_text)
                    content = re.sub(r"\s+", " ", content).strip()

                    if len(content) > 30:
                        rules.append(
                            {
                                "title": title or "BWF Rules",
                                "content": content,
                                "sport": "badminton",
                                "source": "bwfbadminton.com",
                            }
                        )

        # Strategy 4: Fallback — extract meaningful paragraphs
        if not rules:
            paragraphs = soup.find_all("p")
            for p in paragraphs:
                text = p.get_text(separator=" ", strip=True)
                if text and len(text) > 50:
                    rules.append(
                        {
                            "title": "BWF Rule",
                            "content": re.sub(r"\s+", " ", text).strip(),
                            "sport": "badminton",
                            "source": "bwfbadminton.com",
                        }
                    )

        logger.info("Parsed %d rule sections from BWF page", len(rules))
        return rules

    async def scrape_all(self) -> list[dict]:
        """
        Scrape rules from all known BWF URLs.

        Returns:
            A combined list of all parsed rule dicts.
        """
        all_rules: list[dict] = []
        seen_contents: set[str] = set()

        for url in BWF_RULES_URLS:
            try:
                rules = await self.scrape(url)
                for rule in rules:
                    fingerprint = rule["content"][:200].lower()
                    if fingerprint not in seen_contents:
                        seen_contents.add(fingerprint)
                        all_rules.append(rule)
            except Exception as exc:
                logger.error("Failed to scrape BWF URL %s: %s", url, exc)

        logger.info("Total BWF badminton rules scraped: %d", len(all_rules))
        return all_rules
