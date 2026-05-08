"""
Base Scraper Module.

Provides an abstract base class for web scrapers with HTTP fetching,
retry logic, rate limiting, and error handling.
"""

import abc
import asyncio
import logging

import httpx

logger = logging.getLogger(__name__)

DEFAULT_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Accept-Encoding": "gzip, deflate, br",
    "Connection": "keep-alive",
}


class BaseScraper(abc.ABC):
    """Abstract base class for web scrapers with retry and rate limiting."""

    def __init__(
        self,
        max_retries: int = 3,
        retry_delay: float = 2.0,
        request_timeout: float = 30.0,
        rate_limit_delay: float = 1.0,
    ) -> None:
        """
        Initialize the base scraper.

        Args:
            max_retries: Maximum number of retry attempts for failed requests.
            retry_delay: Base delay in seconds between retries (exponential backoff).
            request_timeout: HTTP request timeout in seconds.
            rate_limit_delay: Minimum delay between consecutive requests.
        """
        self.max_retries = max_retries
        self.retry_delay = retry_delay
        self.request_timeout = request_timeout
        self.rate_limit_delay = rate_limit_delay
        self._last_request_time: float = 0.0

    async def _rate_limit(self) -> None:
        """Enforce rate limiting between consecutive requests."""
        now = asyncio.get_event_loop().time()
        elapsed = now - self._last_request_time
        if elapsed < self.rate_limit_delay:
            wait_time = self.rate_limit_delay - elapsed
            logger.debug("Rate limiting: waiting %.2f seconds", wait_time)
            await asyncio.sleep(wait_time)
        self._last_request_time = asyncio.get_event_loop().time()

    async def fetch_page(self, url: str, headers: dict[str, str] | None = None) -> str:
        """
        Fetch a web page with retry logic and error handling.

        Args:
            url: The URL to fetch.
            headers: Optional custom headers to merge with defaults.

        Returns:
            The HTML content as a string.

        Raises:
            httpx.HTTPStatusError: If all retries are exhausted due to HTTP errors.
            httpx.RequestError: If all retries are exhausted due to connection errors.
        """
        merged_headers = {**DEFAULT_HEADERS, **(headers or {})}

        for attempt in range(1, self.max_retries + 1):
            await self._rate_limit()

            try:
                async with httpx.AsyncClient(
                    timeout=self.request_timeout,
                    follow_redirects=True,
                    verify=False,
                ) as client:
                    response = await client.get(url, headers=merged_headers)
                    response.raise_for_status()

                    # Handle encoding issues
                    content_type = response.headers.get("content-type", "")
                    if "charset" in content_type.lower():
                        response.encoding = response.charset_encoding

                    html = response.text
                    logger.info(
                        "Successfully fetched %s (%d bytes, attempt %d/%d)",
                        url,
                        len(html),
                        attempt,
                        self.max_retries,
                    )
                    return html

            except httpx.HTTPStatusError as exc:
                status_code = exc.response.status_code
                logger.warning(
                    "HTTP %d error fetching %s (attempt %d/%d): %s",
                    status_code,
                    url,
                    attempt,
                    self.max_retries,
                    exc,
                )

                # Don't retry on client errors (except 429 Too Many Requests)
                if 400 <= status_code < 500 and status_code != 429:
                    raise

                if attempt < self.max_retries:
                    delay = self.retry_delay * (2 ** (attempt - 1))
                    logger.info("Retrying in %.1f seconds...", delay)
                    await asyncio.sleep(delay)
                else:
                    raise

            except httpx.RequestError as exc:
                logger.warning(
                    "Request error fetching %s (attempt %d/%d): %s",
                    url,
                    attempt,
                    self.max_retries,
                    exc,
                )

                if attempt < self.max_retries:
                    delay = self.retry_delay * (2 ** (attempt - 1))
                    logger.info("Retrying in %.1f seconds...", delay)
                    await asyncio.sleep(delay)
                else:
                    raise

            except Exception as exc:
                logger.error(
                    "Unexpected error fetching %s (attempt %d/%d): %s",
                    url,
                    attempt,
                    self.max_retries,
                    exc,
                )
                if attempt >= self.max_retries:
                    raise
                delay = self.retry_delay * (2 ** (attempt - 1))
                await asyncio.sleep(delay)

        # Should not reach here, but just in case
        raise RuntimeError(f"Failed to fetch {url} after {self.max_retries} attempts")

    @abc.abstractmethod
    def parse(self, html: str) -> list[dict]:
        """
        Parse HTML content and extract structured data.

        Args:
            html: The raw HTML content string.

        Returns:
            A list of dicts with extracted data. Each dict typically contains
            'title', 'content', and sport-specific keys.
        """
        ...

    async def scrape(self, url: str) -> list[dict]:
        """
        Full scraping pipeline: fetch the page, then parse its content.

        Args:
            url: The URL to scrape.

        Returns:
            A list of parsed data dicts.
        """
        logger.info("Scraping URL: %s", url)
        try:
            html = await self.fetch_page(url)
            results = self.parse(html)
            logger.info("Scraped %d items from %s", len(results), url)
            return results
        except Exception as exc:
            logger.error("Scraping failed for %s: %s", url, exc)
            return []
