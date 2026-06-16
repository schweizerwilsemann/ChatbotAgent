"""Bilingual search enrichment for sports knowledge graph nodes.

The source corpus is mostly English while end users ask in Vietnamese.  This
module adds deterministic Vietnamese/English aliases and a combined search_text
field so retrieval can work without calling a translator on every query.
"""

from __future__ import annotations

import re
import unicodedata
from typing import Any

BILINGUAL_PROFILE = "sports-bilingual-alias-v1"

ENTITY_LABELS = (
    "Rule",
    "Technique",
    "Equipment",
    "Sport",
    "Concept",
    "GameType",
)


_PHRASE_ALIASES: dict[str, list[str]] = {
    # Sports
    "badminton": ["cầu lông"],
    "pickleball": ["pickleball"],
    "billiards": ["bida", "billiard", "bida lỗ"],
    "pool": ["bida lỗ"],
    "snooker": ["snooker"],
    "three cushion": ["bida ba băng", "3 băng"],
    # Badminton equipment and court
    "shuttlecock": ["quả cầu", "cầu lông"],
    "racket": ["vợt", "vợt cầu lông"],
    "racquet": ["vợt", "vợt cầu lông"],
    "net": ["lưới"],
    "court": ["sân", "sân cầu lông"],
    "service court": ["ô giao cầu", "vùng giao cầu", "vùng giao bóng"],
    "boundary": ["đường biên"],
    # Badminton rules and techniques
    "service": ["giao cầu", "giao bóng", "phát cầu"],
    "serve": ["giao cầu", "giao bóng", "phát cầu"],
    "serving": ["giao cầu", "giao bóng", "phát cầu"],
    "server": ["người giao cầu", "người giao bóng"],
    "receiver": ["người nhận cầu", "người đỡ giao cầu"],
    "service faults": [
        "lỗi giao cầu",
        "lỗi giao bóng",
        "luật giao bóng cầu lông",
        "luật giao cầu",
    ],
    "fault": ["lỗi", "phạm lỗi"],
    "faults": ["lỗi", "phạm lỗi"],
    "let": ["đánh lại", "let", "cầu lại"],
    "rally": ["pha cầu", "rally"],
    "rally point scoring": ["tính điểm rally", "tính điểm mỗi pha cầu"],
    "scoring system": ["luật tính điểm", "hệ thống tính điểm"],
    "grip": ["cầm vợt", "cách cầm vợt"],
    "forehand grip": ["cầm vợt thuận tay"],
    "backhand grip": ["cầm vợt trái tay"],
    "footwork": ["di chuyển", "bộ chân"],
    "lunge": ["bước với", "lunge", "di chuyển lên lưới"],
    "clear": ["phông cầu", "lốp cầu", "clear"],
    "lob": ["lốp cầu", "phông cầu"],
    "smash": ["đập cầu", "smash"],
    "jump smash": ["đập cầu bật nhảy", "jump smash"],
    "drop shot": ["bỏ nhỏ", "cắt cầu", "drop shot"],
    "drive": ["đánh ngang", "drive"],
    "low serve": ["giao cầu thấp", "giao bóng thấp"],
    "high serve": ["giao cầu cao", "giao bóng cao"],
    "flick serve": ["giao cầu flick", "giao cầu lắc cổ tay"],
    "drive serve": ["giao cầu nhanh", "giao cầu drive"],
    "singles": ["đơn", "đánh đơn"],
    "doubles": ["đôi", "đánh đôi"],
    # Pickleball
    "paddle": ["vợt pickleball"],
    "non-volley zone": ["kitchen", "vùng cấm volley", "vùng non-volley"],
    "kitchen": ["vùng cấm volley", "kitchen"],
    "two-bounce rule": ["luật hai nảy", "luật hai lần nảy"],
    "double bounce rule": ["luật hai nảy", "luật hai lần nảy"],
    "dink": ["dink", "bỏ nhỏ pickleball"],
    "volley": ["volley", "đánh bóng trên không"],
    # Billiards
    "cue": ["cơ bida", "gậy bida"],
    "cue ball": ["bi cái"],
    "object ball": ["bi mục tiêu"],
    "pocket": ["lỗ"],
    "break shot": ["cú phá", "đánh khai cuộc"],
    "push-out": ["push-out", "cú đẩy ra"],
    "ball in hand": ["bi trong tay", "đặt bi cái"],
    "foul": ["lỗi", "phạm lỗi"],
    "diamond system": ["hệ thống diamond", "hệ thống kim cương"],
    "bank shot": ["đánh băng"],
    "kick shot": ["đánh đá băng"],
    "safety": ["đánh an toàn"],
}

_VI_TO_EN_ALIASES: dict[str, list[str]] = {
    "cầu lông": ["badminton", "shuttlecock", "racket"],
    "giao bóng": ["serve", "service", "serving", "server", "receiver"],
    "giao cầu": ["serve", "service", "serving", "server", "receiver"],
    "phát cầu": ["serve", "service", "serving"],
    "lỗi giao bóng": ["service faults", "fault", "service court"],
    "lỗi giao cầu": ["service faults", "fault", "service court"],
    "luật giao bóng": ["service rules", "service faults", "serve", "service"],
    "luật giao cầu": ["service rules", "service faults", "serve", "service"],
    "luật": ["rule", "rules", "regulation", "fault"],
    "quy định": ["rule", "rules", "regulation"],
    "lỗi": ["fault", "foul", "violation"],
    "tính điểm": ["score", "scoring", "rally point"],
    "cách cầm vợt": ["grip", "forehand grip", "backhand grip"],
    "cầm vợt": ["grip", "forehand grip", "backhand grip"],
    "đập cầu": ["smash", "jump smash", "full smash"],
    "bỏ nhỏ": ["drop shot", "fast drop", "slow drop"],
    "phông cầu": ["clear", "lob", "overhead clear"],
    "di chuyển": ["footwork", "lunge", "movement"],
    "bộ chân": ["footwork", "lunge", "movement"],
    "bida": ["billiards", "pool", "cue", "ball"],
    "cơ bida": ["cue"],
    "bi cái": ["cue ball"],
    "bi mục tiêu": ["object ball"],
    "cú phá": ["break shot"],
    "pickleball": ["pickleball", "paddle", "serve", "kitchen"],
    "vùng cấm volley": ["non-volley zone", "kitchen"],
    "luật hai nảy": ["two-bounce rule", "double bounce rule"],
}


def strip_diacritics(text: str) -> str:
    decomposed = unicodedata.normalize("NFKD", str(text).lower())
    return "".join(
        char for char in decomposed if not unicodedata.combining(char)
    ).replace("đ", "d")


def _dedupe(items: list[str]) -> list[str]:
    seen = set()
    result = []
    for item in items:
        value = " ".join(str(item or "").strip().split())
        key = strip_diacritics(value)
        if not value or key in seen:
            continue
        seen.add(key)
        result.append(value)
    return result


def _matched_aliases(text: str, mapping: dict[str, list[str]]) -> list[str]:
    normalized = strip_diacritics(text)
    aliases: list[str] = []
    for phrase, values in mapping.items():
        if strip_diacritics(phrase) in normalized:
            aliases.extend(values)
    return aliases


def build_bilingual_fields(entity: dict[str, Any]) -> dict[str, Any]:
    name = str(entity.get("name") or "")
    description = str(entity.get("description") or "")
    entity_type = str(entity.get("type") or "")
    text = f"{name}\n{description}"

    aliases_vi = _matched_aliases(text, _PHRASE_ALIASES)
    aliases_en = _matched_aliases(text, _VI_TO_EN_ALIASES)

    name_norm = strip_diacritics(name)
    name_vi = ""
    for phrase, values in _PHRASE_ALIASES.items():
        if strip_diacritics(phrase) == name_norm and values:
            name_vi = values[0]
            break

    sport_hint = _sport_aliases(text)
    aliases_vi.extend(sport_hint)
    aliases_en.extend(_matched_aliases(" ".join(sport_hint), _VI_TO_EN_ALIASES))

    aliases_vi = _dedupe(aliases_vi)
    aliases_en = _dedupe(aliases_en)

    search_parts = [
        entity_type,
        name,
        description,
        name_vi,
        " ".join(aliases_vi),
        " ".join(aliases_en),
    ]
    search_text = " ".join(part for part in search_parts if part).strip()

    return {
        "name_vi": name_vi,
        "description_vi": "",
        "aliases_vi": aliases_vi,
        "aliases_en": aliases_en,
        "search_text": search_text,
        "bilingual_profile": BILINGUAL_PROFILE,
    }


def expand_query_terms(query: str) -> list[str]:
    """Return extra bilingual terms for a Vietnamese or English query."""
    text = str(query or "")
    terms: list[str] = []
    terms.extend(_matched_aliases(text, _PHRASE_ALIASES))
    terms.extend(_matched_aliases(text, _VI_TO_EN_ALIASES))
    terms.extend(_sport_aliases(text))

    # Split multi-word aliases so keyword fallback can match partial text too.
    split_terms = []
    for term in terms:
        split_terms.append(term)
        split_terms.extend(re.findall(r"\w+", term.lower(), flags=re.UNICODE))
    return _dedupe(split_terms)


async def sync_bilingual_fields(neo4j_client: Any, limit: int = 1000) -> int:
    """Populate bilingual properties for existing Neo4j knowledge nodes."""
    fetch_query = """
    MATCH (n)
    WHERE n:Rule OR n:Technique OR n:Equipment OR n:Sport
       OR n:Concept OR n:GameType
    RETURN elementId(n) AS node_id,
           n.name AS name,
           head([label IN labels(n)
                 WHERE label IN $entity_labels]) AS type,
           n.description AS description
    ORDER BY n.name
    LIMIT $limit
    """
    nodes = await _execute_query(
        neo4j_client,
        fetch_query,
        {"entity_labels": list(ENTITY_LABELS), "limit": max(1, limit)},
    )
    rows = []
    for node in nodes:
        fields = build_bilingual_fields(node)
        rows.append({"node_id": node["node_id"], **fields})

    if not rows:
        return 0

    update_query = """
    UNWIND $rows AS row
    MATCH (n)
    WHERE elementId(n) = row.node_id
      AND (
        coalesce(n.bilingual_profile, '') <> $profile
        OR coalesce(n.search_text, '') <> row.search_text
      )
    SET n.name_vi = row.name_vi,
        n.description_vi = row.description_vi,
        n.aliases_vi = row.aliases_vi,
        n.aliases_en = row.aliases_en,
        n.search_text = row.search_text,
        n.bilingual_profile = $profile,
        n.bilingual_updated_at = datetime()
    RETURN count(n) AS updated
    """
    result = await _execute_query(
        neo4j_client,
        update_query,
        {"rows": rows, "profile": BILINGUAL_PROFILE},
    )
    return int(result[0]["updated"]) if result else 0


def bilingual_fulltext_index_cypher() -> str:
    return (
        "CREATE FULLTEXT INDEX entity_fulltext_bilingual IF NOT EXISTS "
        "FOR (n:Rule|Technique|Equipment|Sport|Concept|GameType) "
        "ON EACH [n.name, n.description, n.name_vi, n.description_vi, n.search_text]"
    )


async def _execute_query(
    neo4j_client: Any,
    cypher: str,
    params: dict | None = None,
) -> list[dict]:
    if hasattr(neo4j_client, "execute_query") and not hasattr(neo4j_client, "session"):
        return await neo4j_client.execute_query(cypher, params or {})

    async with neo4j_client.session() as session:
        result = await session.run(cypher, params or {})
        return await result.data()


def _sport_aliases(text: str) -> list[str]:
    normalized = strip_diacritics(text)
    aliases = []
    if "badminton" in normalized or "cau long" in normalized:
        aliases.extend(["cầu lông", "badminton"])
    if "pickleball" in normalized:
        aliases.extend(["pickleball"])
    if any(term in normalized for term in ("billiards", "billiard", "bida", "pool")):
        aliases.extend(["bida", "billiards", "pool"])
    return aliases
