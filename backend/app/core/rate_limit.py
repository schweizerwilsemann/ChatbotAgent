import time

from fastapi import HTTPException, Request

from app.core.redis_client import redis_client

_memory_buckets: dict[str, list[float]] = {}


def rate_limit(limit: int, window_seconds: int, scope: str):
    async def _dependency(request: Request) -> None:
        auth = request.headers.get("authorization", "")
        client = request.client.host if request.client else "unknown"
        identity = auth or client
        key = f"rate:{scope}:{identity}"
        now = time.time()

        try:
            raw = await redis_client.get_json(key)
            hits = [float(hit) for hit in raw or [] if now - float(hit) < window_seconds]
            if len(hits) >= limit:
                raise HTTPException(
                    status_code=429,
                    detail="Bạn thao tác quá nhanh. Vui lòng thử lại sau.",
                )
            hits.append(now)
            await redis_client.set_json(key, hits, ex=window_seconds)
            return
        except HTTPException:
            raise
        except Exception:
            hits = [
                hit
                for hit in _memory_buckets.get(key, [])
                if now - hit < window_seconds
            ]
            if len(hits) >= limit:
                raise HTTPException(
                    status_code=429,
                    detail="Bạn thao tác quá nhanh. Vui lòng thử lại sau.",
                )
            hits.append(now)
            _memory_buckets[key] = hits

    return _dependency
