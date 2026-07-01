from typing import Optional

_cache = {}

def get_cached_translation(source_language: str, target_language: str, text: str) -> Optional[str]:
    key = f"{source_language}_{target_language}_{text}"
    return _cache.get(key)

def set_cached_translation(source_language: str, target_language: str, text: str, translated_text: str):
    key = f"{source_language}_{target_language}_{text}"
    _cache[key] = translated_text

def get_cache_size() -> int:
    return len(_cache)
