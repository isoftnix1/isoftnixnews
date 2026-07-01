LANGUAGE_MAPPING = {
    "en": "eng_Latn",
    "hi": "hin_Deva"
}

def get_nllb_lang_code(lang: str) -> str:
    return LANGUAGE_MAPPING.get(lang)
