import re
import unicodedata


_AFFIRMATIVE_MESSAGES = {
    "co",
    "co a",
    "co nhe",
    "dong y",
    "dong y a",
    "ok",
    "okay",
    "ok a",
    "xac nhan",
    "xac nhan a",
    "dat di",
    "dat giup toi",
    "dat giup minh",
    "chot",
    "chot don",
}

_NEGATIVE_MESSAGES = {
    "khong",
    "khong a",
    "khong dat",
    "huy",
    "huy don",
    "thoi",
}


def normalize_message(message: str) -> str:
    """Normalize Vietnamese text for conservative intent checks."""
    text = unicodedata.normalize("NFD", message.lower().strip())
    text = "".join(char for char in text if not unicodedata.combining(char))
    text = text.replace("đ", "d")
    text = re.sub(r"[^a-z0-9\s]", " ", text)
    return " ".join(text.split())


def is_affirmative_message(message: str) -> bool:
    return normalize_message(message) in _AFFIRMATIVE_MESSAGES


def is_negative_message(message: str) -> bool:
    return normalize_message(message) in _NEGATIVE_MESSAGES


def is_order_note_question(message: str) -> bool:
    normalized = normalize_message(message)
    return (
        "yeu cau dac biet" in normalized
        or (
            "ghi chu" in normalized
            and any(word in normalized for word in ("co khong", "gi khong", "them"))
        )
    )


def is_order_confirmation_prompt(message: str) -> bool:
    normalized = normalize_message(message)
    return (
        "xac nhan" in normalized
        and "ghi chu" in normalized
        and any(word in normalized for word in ("dat", "goi", "thue", "mua"))
    )


def latest_assistant_message(history: list[dict] | None) -> str:
    for entry in reversed(history or []):
        if entry.get("role") == "assistant":
            return str(entry.get("content") or "")
    return ""


def _confirmation_flow_is_complete(history: list[dict]) -> bool:
    confirmation_index = None
    for index in range(len(history) - 1, -1, -1):
        entry = history[index]
        if entry.get("role") == "assistant" and is_order_confirmation_prompt(
            str(entry.get("content") or "")
        ):
            confirmation_index = index
            break
    if confirmation_index is None:
        return False

    note_question_index = None
    for index in range(confirmation_index - 1, -1, -1):
        entry = history[index]
        if entry.get("role") == "assistant" and is_order_note_question(
            str(entry.get("content") or "")
        ):
            note_question_index = index
            break
    if note_question_index is None:
        return False

    has_order_request = any(
        entry.get("role") == "user" for entry in history[:note_question_index]
    )
    has_note_answer = any(
        entry.get("role") == "user"
        for entry in history[note_question_index + 1 : confirmation_index]
    )
    has_confirmation_answer = any(
        entry.get("role") == "user" for entry in history[confirmation_index + 1 :]
    )
    return has_order_request and has_note_answer and has_confirmation_answer


def order_creation_is_confirmed(context: dict | None) -> bool:
    """Require an explicit confirmation turn before an order tool may write."""
    context = context or {}
    current_message = str(context.get("_current_user_message") or "")
    history = context.get("_session_history")
    if not isinstance(history, list):
        return False

    return (
        is_affirmative_message(current_message)
        and is_order_confirmation_prompt(latest_assistant_message(history))
        and _confirmation_flow_is_complete(history)
    )


def order_payload_matches_confirmation(
    context: dict | None,
    items: list[dict],
    notes: str,
) -> bool:
    history = (context or {}).get("_session_history")
    if not isinstance(history, list):
        return False

    confirmation = normalize_message(latest_assistant_message(history))
    normalized_notes = normalize_message(notes or "Không có")
    if normalized_notes not in confirmation:
        return False

    for item in items:
        if not isinstance(item, dict):
            return False
        item_name = normalize_message(str(item.get("item_name") or ""))
        try:
            quantity = int(item.get("quantity"))
        except (TypeError, ValueError):
            return False

        if not item_name or quantity < 1:
            return False

        name_words = item_name.split()
        name_matches = item_name in confirmation or all(
            word in confirmation for word in name_words
        )
        quantity_before = re.search(
            rf"\b{quantity}\s+(?:ly\s+|chai\s+|lon\s+|phan\s+|cai\s+)?"
            rf"{re.escape(item_name)}\b",
            confirmation,
        )
        quantity_after = re.search(
            rf"\b{re.escape(item_name)}\s+x?\s*{quantity}\b",
            confirmation,
        )
        if not name_matches or not (quantity_before or quantity_after):
            return False
    return True


def strip_internal_context(message: str) -> str:
    """Remove the server-added context line from a stored user message."""
    lines = message.splitlines()
    if lines and lines[0].startswith("[Ngữ cảnh hiện tại:"):
        return "\n".join(lines[1:]).strip()
    return message.strip()
