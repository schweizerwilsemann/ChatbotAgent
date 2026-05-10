"""Tests for IntentRouter — keyword fallback mode (no embedder).

When constructed without an embedder the router uses keyword matching.
When constructed WITH an embedder it pre-computes intent embeddings
and routes via cosine similarity.
"""

import pytest
from app.agent.intent_router import IntentRouter

# ── Keyword-fallback router (no embedder) ─────────────────────────────
router = IntentRouter()  # No embedder → keyword-fallback mode


class TestStripDiacritics:
    def test_plain_ascii_unchanged(self):
        assert router._strip_diacritics("hello") == "hello"

    def test_vietnamese_diacritics(self):
        assert router._strip_diacritics("chào") == "chao"
        assert router._strip_diacritics("luật") == "luat"
        assert router._strip_diacritics("cầu lông") == "cau long"
        assert router._strip_diacritics("kỹ thuật") == "ky thuat"

    def test_mixed(self):
        assert router._strip_diacritics("pickleball") == "pickleball"


class TestCosineSimilarity:
    def test_identical_vectors(self):
        v = [1.0, 0.0, 0.0]
        assert IntentRouter._cosine(v, v) == pytest.approx(1.0)

    def test_orthogonal_vectors(self):
        a = [1.0, 0.0, 0.0]
        b = [0.0, 1.0, 0.0]
        assert IntentRouter._cosine(a, b) == pytest.approx(0.0)

    def test_opposite_vectors(self):
        a = [1.0, 0.0]
        b = [-1.0, 0.0]
        assert IntentRouter._cosine(a, b) == pytest.approx(-1.0)

    def test_zero_vector(self):
        assert IntentRouter._cosine([0.0, 0.0], [1.0, 0.0]) == 0.0


class TestKwMatch:
    def test_single_word_match(self):
        assert router._kw_match("chao ban", ("chào",)) is True

    def test_single_word_no_match(self):
        assert router._kw_match("chao ban", ("hello",)) is False

    def test_multi_word_match(self):
        assert router._kw_match("xin chao ban", ("xin chào",)) is True

    def test_multi_word_no_match(self):
        assert router._kw_match("ban chao xin", ("xin chào",)) is False


# ── Keyword-fallback routing tests ────────────────────────────────────
@pytest.mark.asyncio
class TestKeywordRouteGreetings:
    """Greetings without diacritics should NOT be blocked."""

    async def test_chao_ban_passes(self):
        result = await router.route("chao ban")
        assert result is None

    async def test_xin_chao_passes(self):
        result = await router.route("xin chao")
        assert result is None

    async def test_hello_passes(self):
        result = await router.route("hello")
        assert result is None

    async def test_hi_passes(self):
        result = await router.route("hi")
        assert result is None

    async def test_short_message_passes(self):
        result = await router.route("ok")
        assert result is None

    async def test_oi_ban_passes(self):
        result = await router.route("oi ban")
        assert result is None


@pytest.mark.asyncio
class TestKeywordRouteDomainQueries:
    async def test_pickleball_query_passes(self):
        result = await router.route("cho toi biet luat pickleball")
        assert result is None

    async def test_bida_query_passes(self):
        result = await router.route("ky thuat bida")
        assert result is None

    async def test_dat_san_passes(self):
        result = await router.route("dat san")
        assert result is None


@pytest.mark.asyncio
class TestKeywordRouteOffTopic:
    async def test_random_off_topic(self):
        result = await router.route("thời tiết hôm nay thế nào")
        assert result is not None
        assert "chỉ hỗ trợ" in result.answer

    async def test_cooking_question(self):
        result = await router.route("cách nấu phở ngon")
        assert result is not None
        assert "chỉ hỗ trợ" in result.answer


@pytest.mark.asyncio
class TestKeywordSupportedSportsQuestion:
    async def test_with_diacritics(self):
        result = await router.route("những môn nào được hỗ trợ về kiến thức")
        assert result is not None
        assert "Bida" in result.answer
        assert "Pickleball" in result.answer

    async def test_without_diacritics(self):
        result = await router.route("nhung mon nao duoc ho tro ve kien thuc")
        assert result is not None
        assert "Bida" in result.answer
