import torch
import re
from .model import get_model, get_tokenizer
from .language_mapper import get_nllb_lang_code
from .cache import get_cached_translation, set_cached_translation

# Maximum characters per chunk sent to the model.
# NLLB-200 has a 512-token input limit; ~500 chars safely stays within that.
MAX_CHUNK_CHARS = 500

def is_meaningful_text(text: str) -> bool:
    if not text:
        return False

    s = str(text).strip()
    if not s:
        return False

    # Check if UUID or ID
    if re.match(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$', s):
        return False

    # Check if URL
    if re.match(r'^https?://[^\s/$.?#].[^\s]*$', s):
        return False

    # Check if Date (simple check YYYY-MM-DD or ISO)
    if re.match(r'^\d{4}-\d{2}-\d{2}', s):
        return False

    # Check if pure number
    if s.isnumeric():
        return False

    return True


def _split_into_chunks(text: str) -> list[str]:
    """
    Split text into translatable chunks while preserving paragraph boundaries.

    Strategy:
    1. Split on double-newlines (paragraph breaks) first.
    2. If a paragraph exceeds MAX_CHUNK_CHARS, split it further on sentence
       boundaries (. ! ?) to keep each chunk within the model's token limit.
    3. Empty paragraphs (blank lines) are preserved as sentinel markers so the
       final join can restore the original blank-line structure.
    """
    # Split on paragraph breaks, keeping blank entries to track spacing
    paragraphs = text.split('\n\n')
    chunks = []  # list of (chunk_text, separator_after)

    for para in paragraphs:
        para_stripped = para.strip()
        if not para_stripped:
            # Preserve the blank paragraph as a gap marker
            chunks.append(('', True))
            continue

        if len(para_stripped) <= MAX_CHUNK_CHARS:
            chunks.append((para_stripped, True))
        else:
            # Split long paragraph on sentence boundaries
            sentences = re.split(r'(?<=[.!?])\s+', para_stripped)
            current = ''
            for sentence in sentences:
                if len(current) + len(sentence) + 1 <= MAX_CHUNK_CHARS:
                    current = (current + ' ' + sentence).strip()
                else:
                    if current:
                        chunks.append((current, False))
                    # If a single sentence is still too long, hard-split it
                    if len(sentence) > MAX_CHUNK_CHARS:
                        for i in range(0, len(sentence), MAX_CHUNK_CHARS):
                            sub = sentence[i:i + MAX_CHUNK_CHARS].strip()
                            if sub:
                                chunks.append((sub, False))
                        current = ''
                    else:
                        current = sentence
            if current:
                chunks.append((current, True))  # last piece of paragraph

    return chunks


def _translate_chunk(text: str, source_lang_nllb: str, target_lang_nllb: str) -> str:
    """Translate a single chunk using the loaded NLLB model."""
    model = get_model()
    tokenizer = get_tokenizer()

    tokenizer.src_lang = source_lang_nllb
    inputs = tokenizer(text, return_tensors='pt', truncation=True, max_length=512)

    if torch.cuda.is_available():
        inputs = inputs.to('cuda')

    forced_bos_token_id = tokenizer.lang_code_to_id[target_lang_nllb]

    outputs = model.generate(
        **inputs,
        forced_bos_token_id=forced_bos_token_id,
        max_new_tokens=512,    # controls output length independently of input
        num_beams=4,
        early_stopping=True,
    )

    return tokenizer.batch_decode(outputs, skip_special_tokens=True)[0]


def translate(text: str, source_language: str, target_language: str) -> tuple[str, bool]:
    if not is_meaningful_text(text):
        return text, False

    if source_language == target_language:
        return text, False

    # Full-text cache check — instant return on repeated requests
    cached_val = get_cached_translation(source_language, target_language, text)
    if cached_val is not None:
        return cached_val, True

    source_lang_nllb = get_nllb_lang_code(source_language)
    target_lang_nllb = get_nllb_lang_code(target_language)

    if not source_lang_nllb or not target_lang_nllb:
        return text, False

    chunks = _split_into_chunks(text)
    translated_parts = []

    for chunk_text, is_paragraph_end in chunks:
        if not chunk_text:
            # Blank paragraph — preserve as double newline gap
            translated_parts.append('')
            continue

        # Per-chunk cache check to avoid re-translating identical paragraphs
        cached_chunk = get_cached_translation(source_language, target_language, chunk_text)
        if cached_chunk is not None:
            translated_chunk = cached_chunk
        else:
            translated_chunk = _translate_chunk(chunk_text, source_lang_nllb, target_lang_nllb)
            set_cached_translation(source_language, target_language, chunk_text, translated_chunk)

        translated_parts.append(translated_chunk)

    # Reconstruct: join sentence-level chunks with a space, paragraph-level with \n\n.
    # We rely on the is_paragraph_end flag to know where \n\n goes.
    result_paragraphs = []
    current_paragraph_pieces = []

    for i, (chunk_text, is_paragraph_end) in enumerate(chunks):
        translated = translated_parts[i]
        if not chunk_text:
            # Flush current paragraph and insert blank line
            if current_paragraph_pieces:
                result_paragraphs.append(' '.join(current_paragraph_pieces))
                current_paragraph_pieces = []
            result_paragraphs.append('')  # blank line
        elif is_paragraph_end:
            current_paragraph_pieces.append(translated)
            result_paragraphs.append(' '.join(current_paragraph_pieces))
            current_paragraph_pieces = []
        else:
            current_paragraph_pieces.append(translated)

    if current_paragraph_pieces:
        result_paragraphs.append(' '.join(current_paragraph_pieces))

    final_translation = '\n\n'.join(result_paragraphs)

    # Cache the full translated result for future identical full-text requests
    set_cached_translation(source_language, target_language, text, final_translation)
    return final_translation, False
