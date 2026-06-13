import re
from enum import Enum


class VietnamMobileCarrier(str, Enum):
    VIETTEL = "Viettel"
    VINAPHONE = "VinaPhone"
    MOBIFONE = "MobiFone"


_CARRIER_PREFIXES = {
    VietnamMobileCarrier.VIETTEL: {
        "032",
        "033",
        "034",
        "035",
        "036",
        "037",
        "038",
        "039",
        "086",
        "096",
        "097",
        "098",
    },
    VietnamMobileCarrier.VINAPHONE: {
        "081",
        "082",
        "083",
        "084",
        "085",
        "088",
        "091",
        "094",
    },
    VietnamMobileCarrier.MOBIFONE: {
        "070",
        "076",
        "077",
        "078",
        "079",
        "089",
        "090",
        "093",
    },
}


def normalize_vietnam_phone(phone: str) -> str:
    """Normalize a Vietnamese phone number to the domestic 0xxxxxxxxx form."""
    normalized = re.sub(r"[\s().-]", "", phone.strip())
    if normalized.startswith("+84"):
        return f"0{normalized[3:]}"
    if normalized.startswith("84") and len(normalized) == 11:
        return f"0{normalized[2:]}"
    return normalized


def identify_major_mobile_carrier(
    phone: str,
) -> VietnamMobileCarrier | None:
    """Identify the original carrier allocation from a Vietnamese mobile prefix."""
    normalized = normalize_vietnam_phone(phone)
    if re.fullmatch(r"0\d{9}", normalized) is None:
        return None

    prefix = normalized[:3]
    for carrier, prefixes in _CARRIER_PREFIXES.items():
        if prefix in prefixes:
            return carrier
    return None
