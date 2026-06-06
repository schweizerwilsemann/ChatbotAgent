import json
import logging
import time
from typing import Any

import redis.asyncio as aioredis

from app.core.config import settings

logger = logging.getLogger(__name__)


class RedisClient:
    def __init__(self) -> None:
        self._client: aioredis.Redis | None = None
        self._memory: dict[str, tuple[str, float | None]] = {}

    async def connect(self) -> None:
        try:
            self._client = aioredis.from_url(
                settings.REDIS_URL,
                encoding="utf-8",
                decode_responses=True,
            )
            await self._client.ping()
            logger.info("Redis connected at %s", settings.REDIS_URL)
        except Exception:
            self._client = None
            logger.warning(
                "Redis unavailable at %s; using in-memory dev cache",
                settings.REDIS_URL,
                exc_info=True,
            )

    async def close(self) -> None:
        if self._client:
            await self._client.close()
            self._client = None
            logger.info("Redis connection closed.")

    @property
    def client(self) -> aioredis.Redis:
        if not self._client:
            raise RuntimeError("Redis client is not initialised. Call connect() first.")
        return self._client

    async def get(self, key: str) -> str | None:
        if self._client:
            return await self._client.get(key)
        item = self._memory.get(key)
        if item is None:
            return None
        value, expires_at = item
        if expires_at is not None and expires_at <= time.time():
            self._memory.pop(key, None)
            return None
        return value

    async def set(self, key: str, value: str, ex: int | None = None) -> None:
        if self._client:
            await self._client.set(key, value, ex=ex)
            return
        expires_at = time.time() + ex if ex else None
        self._memory[key] = (value, expires_at)

    async def get_json(self, key: str) -> Any | None:
        raw = await self.get(key)
        if raw is None:
            return None
        return json.loads(raw)

    async def set_json(self, key: str, value: Any, ex: int | None = None) -> None:
        await self.set(key, json.dumps(value, ensure_ascii=False), ex=ex)

    async def expire(self, key: str, seconds: int) -> None:
        if self._client:
            await self._client.expire(key, seconds)
            return
        item = self._memory.get(key)
        if item:
            self._memory[key] = (item[0], time.time() + seconds)

    async def delete(self, key: str) -> None:
        if self._client:
            await self._client.delete(key)
            return
        self._memory.pop(key, None)

    async def exists(self, key: str) -> bool:
        if self._client:
            return bool(await self._client.exists(key))
        return await self.get(key) is not None

    async def publish(self, channel: str, value: Any) -> None:
        if not self._client:
            return
        payload = value if isinstance(value, str) else json.dumps(value, ensure_ascii=False)
        await self._client.publish(channel, payload)

    async def rpush(self, key: str, value: str) -> None:
        if self._client:
            await self._client.rpush(key, value)
            return
        # In-memory fallback: simulate list with comma-separated string
        existing = self._memory.get(key, (None, None))[0]
        items = json.loads(existing) if existing else []
        items.append(value)
        self._memory[key] = (json.dumps(items), self._memory.get(key, (None, None))[1])

    async def lrange(self, key: str, start: int, stop: int) -> list[str]:
        if self._client:
            return await self._client.lrange(key, start, stop)
        raw = self._memory.get(key, (None, None))[0]
        if not raw:
            return []
        items = json.loads(raw)
        if stop == -1:
            return items[start:]
        return items[start : stop + 1]

    async def ltrim(self, key: str, start: int, stop: int) -> None:
        if self._client:
            await self._client.ltrim(key, start, stop)
            return
        raw = self._memory.get(key, (None, None))[0]
        if not raw:
            return
        items = json.loads(raw)
        if stop == -1:
            trimmed = items[start:]
        else:
            trimmed = items[start : stop + 1]
        self._memory[key] = (json.dumps(trimmed), self._memory.get(key, (None, None))[1])

    async def llen(self, key: str) -> int:
        if self._client:
            return await self._client.llen(key)
        raw = self._memory.get(key, (None, None))[0]
        if not raw:
            return 0
        return len(json.loads(raw))

    async def scan_keys(self, pattern: str) -> list[str]:
        if self._client:
            keys = []
            async for key in self._client.scan_iter(match=pattern, count=100):
                keys.append(key)
            return keys
        import fnmatch
        return [k for k in self._memory if fnmatch.fnmatch(k, pattern)]


redis_client = RedisClient()
