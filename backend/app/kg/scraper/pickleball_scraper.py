"""
Pickleball Scraper Module.

Scrapes pickleball rules from USA Pickleball (usapickleball.org)
and returns structured data for knowledge graph construction.
"""

import logging
import re

from bs4 import BeautifulSoup, Tag

from .base_scraper import BaseScraper

logger = logging.getLogger(__name__)

PICKLEBALL_RULES_URLS = [
    "https://usapickleball.org/what-is-pickleball/official-rules/",
    "https://usapickleball.org/what-is-pickleball/",
    "https://usapickleball.org/rules/",
]


class PickleballScraper(BaseScraper):
    """Scraper for USA Pickleball rules from usapickleball.org."""

    def __init__(self, **kwargs) -> None:
        """Initialize the Pickleball scraper."""
        super().__init__(**kwargs)

    def parse(self, html: str) -> list[dict]:
        """
        Parse USA Pickleball rules page HTML and extract rule sections.

        Args:
            html: The raw HTML content from usapickleball.org.

        Returns:
            A list of dicts with 'title', 'content', and 'sport' keys.
        """
        if not html or not html.strip():
            logger.warning("Empty HTML provided to Pickleball parser")
            return []

        try:
            soup = BeautifulSoup(html, "html.parser")
        except Exception as exc:
            logger.error("Failed to parse Pickleball HTML: %s", exc)
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

        # Strategy 1: Extract rule sections by headings
        headings = soup.find_all(re.compile(r"^h[1-4]$"))

        for i, heading in enumerate(headings):
            title = heading.get_text(strip=True)
            if not title or len(title) < 3:
                continue

            # Filter out navigation/headings that aren't rules
            if any(
                skip in title.lower()
                for skip in [
                    "menu",
                    "search",
                    "login",
                    "register",
                    "contact",
                    "about us",
                    "privacy",
                    "terms",
                    "cookie",
                    "subscribe",
                    "newsletter",
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
                        "sport": "pickleball",
                        "source": "usapickleball.org",
                    }
                )

        # Strategy 2: Look for rule-specific sections with structured HTML
        if len(rules) < 3:
            rule_containers = soup.find_all(
                ["div", "section", "article"],
                class_=re.compile(
                    r"(rule|content|entry|post|article|body|section)", re.IGNORECASE
                ),
            )

            for container in rule_containers:
                if not isinstance(container, Tag):
                    continue

                # Look for rule numbers like "Rule 1" or "Section 2"
                rule_number_match = container.find(
                    string=re.compile(r"^(Rule|Section|Article)\s*\d+", re.IGNORECASE)
                )
                title = ""
                if rule_number_match:
                    title = rule_number_match.strip()
                else:
                    title_tag = container.find(re.compile(r"^h[1-5]$"))
                    if title_tag:
                        title = title_tag.get_text(strip=True)

                # Extract content
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
                                "title": title or "Pickleball Rule",
                                "content": content,
                                "sport": "pickleball",
                                "source": "usapickleball.org",
                            }
                        )

        # Strategy 3: Extract list items that look like rules
        if not rules:
            list_items = soup.find_all("li")
            current_title = ""
            current_content: list[str] = []

            for li in list_items:
                text = li.get_text(separator=" ", strip=True)
                if not text or len(text) < 10:
                    continue

                # Check if this looks like a rule number
                if re.match(r"^\d+[\.\):]", text) or re.match(
                    r"^(Rule|Section)\s*\d+", text, re.IGNORECASE
                ):
                    # Save previous rule if exists
                    if current_content:
                        content = " ".join(current_content)
                        if len(content) > 20:
                            rules.append(
                                {
                                    "title": current_title or "Pickleball Rule",
                                    "content": re.sub(r"\s+", " ", content).strip(),
                                    "sport": "pickleball",
                                    "source": "usapickleball.org",
                                }
                            )
                    current_title = text[:100]
                    current_content = [text]
                else:
                    current_content.append(text)

            # Don't forget the last rule
            if current_content:
                content = " ".join(current_content)
                if len(content) > 20:
                    rules.append(
                        {
                            "title": current_title or "Pickleball Rule",
                            "content": re.sub(r"\s+", " ", content).strip(),
                            "sport": "pickleball",
                            "source": "usapickleball.org",
                        }
                    )

        # Strategy 4: Fallback — extract paragraphs
        if not rules:
            paragraphs = soup.find_all("p")
            for p in paragraphs:
                text = p.get_text(separator=" ", strip=True)
                if text and len(text) > 50:
                    rules.append(
                        {
                            "title": "Pickleball Rule",
                            "content": re.sub(r"\s+", " ", text).strip(),
                            "sport": "pickleball",
                            "source": "usapickleball.org",
                        }
                    )

        logger.info("Parsed %d rule sections from Pickleball page", len(rules))
        return rules

    async def scrape_all(self) -> list[dict]:
        """
        Scrape rules from all known Pickleball URLs.

        Returns:
            A combined list of all parsed rule dicts.
        """
        all_rules: list[dict] = []
        seen_contents: set[str] = set()

        for url in PICKLEBALL_RULES_URLS:
            try:
                rules = await self.scrape(url)
                for rule in rules:
                    fingerprint = rule["content"][:200].lower()
                    if fingerprint not in seen_contents:
                        seen_contents.add(fingerprint)
                        all_rules.append(rule)
            except Exception as exc:
                logger.error("Failed to scrape Pickleball URL %s: %s", url, exc)

        logger.info("Total Pickleball rules scraped: %d", len(all_rules))
        return all_rules
