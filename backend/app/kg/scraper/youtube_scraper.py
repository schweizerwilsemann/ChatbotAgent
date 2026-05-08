"""
YouTube Scraper Module.

Uses yt-dlp to download and extract transcripts/subtitles from YouTube videos
related to billiards, pickleball, and badminton techniques.
"""

import asyncio
import json
import logging
import re
import tempfile
from pathlib import Path

logger = logging.getLogger(__name__)

SPORT_SEARCH_QUERIES = {
    "billiards": [
        "billiards techniques tutorial",
        "pool billiards rules explained",
        "billiards cue ball control",
        "8 ball pool strategy",
        "snooker techniques",
    ],
    "pickleball": [
        "pickleball techniques tutorial",
        "pickleball rules explained",
        "pickleball serve technique",
        "pickleball strategy beginners",
        "pickleball doubles strategy",
    ],
    "badminton": [
        "badminton techniques tutorial",
        "badminton rules explained",
        "badminton smash technique",
        "badminton footwork training",
        "badminton singles strategy",
    ],
}


class YouTubeScraper:
    """Scrapes YouTube video transcripts using yt-dlp."""

    def __init__(
        self,
        max_retries: int = 3,
        request_timeout: float = 60.0,
        rate_limit_delay: float = 2.0,
    ) -> None:
        """
        Initialize the YouTube scraper.

        Args:
            max_retries: Maximum retry attempts for video operations.
            request_timeout: Timeout for yt-dlp operations in seconds.
            rate_limit_delay: Minimum delay between YouTube requests.
        """
        self.max_retries = max_retries
        self.request_timeout = request_timeout
        self.rate_limit_delay = rate_limit_delay

    async def _run_ytdlp(self, args: list[str]) -> str:
        """
        Run yt-dlp as a subprocess and return stdout.

        Args:
            args: Command-line arguments for yt-dlp.

        Returns:
            The stdout output from yt-dlp.

        Raises:
            RuntimeError: If yt-dlp fails or is not installed.
        """
        cmd = ["yt-dlp"] + args
        logger.debug("Running yt-dlp: %s", " ".join(cmd))

        try:
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, stderr = await asyncio.wait_for(
                process.communicate(), timeout=self.request_timeout
            )

            stdout_text = stdout.decode("utf-8", errors="replace").strip()
            stderr_text = stderr.decode("utf-8", errors="replace").strip()

            if process.returncode != 0:
                logger.warning("yt-dlp stderr: %s", stderr_text[:500])
                if "not found" in stderr_text.lower() or process.returncode == 127:
                    raise RuntimeError(
                        "yt-dlp is not installed. Install with: pip install yt-dlp"
                    )
                # Return stdout even on non-zero exit if we got content
                if stdout_text:
                    return stdout_text
                raise RuntimeError(
                    f"yt-dlp exited with code {process.returncode}: {stderr_text[:300]}"
                )

            return stdout_text

        except asyncio.TimeoutError:
            logger.error("yt-dlp timed out after %.0f seconds", self.request_timeout)
            raise RuntimeError(f"yt-dlp timed out after {self.request_timeout}s")
        except FileNotFoundError:
            raise RuntimeError(
                "yt-dlp is not installed. Install with: pip install yt-dlp"
            )

    async def get_transcript(self, video_url: str) -> str | None:
        """
        Download and extract transcript/subtitles from a YouTube video.

        Tries auto-generated subtitles first, then manual subtitles.
        Falls back to English, then any available language.

        Args:
            video_url: The YouTube video URL.

        Returns:
            The transcript text, or None if no transcript is available.
        """
        for attempt in range(1, self.max_retries + 1):
            try:
                with tempfile.TemporaryDirectory() as tmp_dir:
                    tmp_path = Path(tmp_dir)
                    sub_file = tmp_path / "transcript"

                    # Try auto-generated subtitles first (English), then manual
                    subtitle_args = [
                        video_url,
                        "--write-auto-sub",
                        "--write-sub",
                        "--sub-lang",
                        "en,en-US,en-GB",
                        "--sub-format",
                        "vtt",
                        "--skip-download",
                        "-o",
                        str(sub_file),
                        "--no-warnings",
                    ]

                    try:
                        await self._run_ytdlp(subtitle_args)
                    except RuntimeError:
                        logger.debug("No subtitles found for %s", video_url)
                        return None

                    # Find the subtitle file
                    subtitle_files = list(tmp_path.glob("*.vtt"))
                    if not subtitle_files:
                        subtitle_files = list(tmp_path.glob("*.srt"))

                    if not subtitle_files:
                        logger.debug("No subtitle files generated for %s", video_url)
                        return None

                    # Read and clean the subtitle file
                    subtitle_content = subtitle_files[0].read_text(
                        encoding="utf-8", errors="replace"
                    )
                    transcript = self._clean_subtitle_text(subtitle_content)

                    if transcript and len(transcript) > 20:
                        logger.info(
                            "Extracted transcript from %s (%d chars)",
                            video_url,
                            len(transcript),
                        )
                        return transcript

                    return None

            except Exception as exc:
                logger.warning(
                    "Transcript extraction attempt %d/%d failed for %s: %s",
                    attempt,
                    self.max_retries,
                    video_url,
                    exc,
                )
                if attempt < self.max_retries:
                    await asyncio.sleep(self.rate_limit_delay * attempt)

        logger.error("Failed to extract transcript from %s", video_url)
        return None

    def _clean_subtitle_text(self, raw_text: str) -> str:
        """
        Clean VTT/SRT subtitle text into plain transcript text.

        Args:
            raw_text: Raw VTT or SRT subtitle content.

        Returns:
            Cleaned plain text transcript.
        """
        lines = raw_text.split("\n")
        seen_lines: set[str] = set()
        clean_lines: list[str] = []

        for line in lines:
            line = line.strip()

            # Skip VTT headers, timestamps, empty lines, numeric-only lines
            if not line:
                continue
            if line.startswith("WEBVTT"):
                continue
            if line.startswith("Kind:") or line.startswith("Language:"):
                continue
            if re.match(r"^\d+$", line):
                continue
            # Timestamp lines (SRT or VTT)
            if re.match(r"^\d{2}:\d{2}", line):
                continue
            if "-->" in line:
                continue
            # HTML tags in subtitles
            cleaned = re.sub(r"<[^>]+>", "", line)
            cleaned = cleaned.strip()
            if not cleaned or len(cleaned) < 2:
                continue

            # Deduplicate consecutive repeated lines
            if cleaned not in seen_lines:
                seen_lines.add(cleaned)
                clean_lines.append(cleaned)

        transcript = " ".join(clean_lines)
        # Clean up extra whitespace
        transcript = re.sub(r"\s+", " ", transcript).strip()
        return transcript

    async def get_video_info(self, video_url: str) -> dict | None:
        """
        Get metadata for a YouTube video.

        Args:
            video_url: The YouTube video URL.

        Returns:
            A dict with 'title', 'url', 'channel', 'description', or None on failure.
        """
        try:
            info_args = [
                video_url,
                "--dump-json",
                "--no-download",
                "--no-warnings",
            ]

            output = await self._run_ytdlp(info_args)
            info = json.loads(output)

            return {
                "title": info.get("title", ""),
                "url": video_url,
                "channel": info.get("uploader", info.get("channel", "")),
                "description": (info.get("description") or "")[:500],
                "duration": info.get("duration", 0),
                "view_count": info.get("view_count", 0),
            }

        except (json.JSONDecodeError, RuntimeError) as exc:
            logger.error("Failed to get video info for %s: %s", video_url, exc)
            return None

    async def search_videos(self, query: str, max_results: int = 5) -> list[dict]:
        """
        Search YouTube for videos matching a query.

        Args:
            query: The search query string.
            max_results: Maximum number of results to return.

        Returns:
            A list of dicts with video metadata.
        """
        try:
            search_args = [
                f"ytsearch{max_results}:{query}",
                "--dump-json",
                "--no-download",
                "--no-warnings",
                "--flat-playlist",
            ]

            output = await self._run_ytdlp(search_args)

            videos = []
            for line in output.strip().split("\n"):
                if not line.strip():
                    continue
                try:
                    info = json.loads(line)
                    video_url = info.get("url") or info.get("webpage_url") or ""
                    if not video_url and info.get("id"):
                        video_url = f"https://www.youtube.com/watch?v={info['id']}"

                    videos.append(
                        {
                            "title": info.get("title", ""),
                            "url": video_url,
                            "channel": info.get("uploader", info.get("channel", "")),
                            "duration": info.get("duration", 0),
                            "view_count": info.get("view_count", 0),
                        }
                    )
                except json.JSONDecodeError:
                    continue

            logger.info(
                "YouTube search for '%s' returned %d videos", query, len(videos)
            )
            return videos

        except Exception as exc:
            logger.error("YouTube search failed for '%s': %s", query, exc)
            return []

    async def search_and_transcript(
        self,
        query: str,
        max_results: int = 5,
        sport: str = "general",
    ) -> list[dict]:
        """
        Search YouTube for videos and extract their transcripts.

        Args:
            query: The search query string.
            max_results: Maximum number of videos to process.
            sport: The sport context for tagging results.

        Returns:
            A list of dicts with 'title', 'url', 'transcript', and 'sport' keys.
        """
        videos = await self.search_videos(query, max_results=max_results)

        results = []
        for video in videos:
            video_url = video.get("url", "")
            if not video_url:
                continue

            logger.info("Extracting transcript for: %s", video.get("title", ""))
            transcript = await self.get_transcript(video_url)

            if transcript and len(transcript) > 50:
                results.append(
                    {
                        "title": video.get("title", ""),
                        "url": video_url,
                        "transcript": transcript,
                        "sport": sport,
                        "channel": video.get("channel", ""),
                        "source": "youtube",
                    }
                )

            # Rate limiting between videos
            await asyncio.sleep(self.rate_limit_delay)

        logger.info(
            "Got transcripts for %d/%d videos for query '%s'",
            len(results),
            len(videos),
            query,
        )
        return results

    async def scrape_sport_techniques(
        self,
        sport: str,
        max_videos_per_query: int = 3,
    ) -> list[dict]:
        """
        Scrape technique videos for a specific sport.

        Args:
            sport: The sport name (billiards, pickleball, badminton).
            max_videos_per_query: Max videos per search query.

        Returns:
            A list of dicts with video transcripts and metadata.
        """
        queries = SPORT_SEARCH_QUERIES.get(sport.lower(), [])
        if not queries:
            logger.warning("No search queries defined for sport '%s'", sport)
            return []

        all_results: list[dict] = []
        seen_urls: set[str] = set()

        for query in queries:
            try:
                results = await self.search_and_transcript(
                    query,
                    max_results=max_videos_per_query,
                    sport=sport,
                )
                for result in results:
                    url = result.get("url", "")
                    if url and url not in seen_urls:
                        seen_urls.add(url)
                        all_results.append(result)
            except Exception as exc:
                logger.error("Failed to scrape for query '%s': %s", query, exc)

        logger.info(
            "Scraped %d technique transcripts for sport '%s'",
            len(all_results),
            sport,
        )
        return all_results
