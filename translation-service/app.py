import os
import time
import uuid
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from dotenv import load_dotenv

from translator.model import load_model
from translator.translator import translate
from translator.language_mapper import LANGUAGE_MAPPING
from translator.cache import get_cache_size

load_dotenv()

@asynccontextmanager
async def lifespan(app: FastAPI):
    load_model()
    print("Supported Languages:")
    for lang in LANGUAGE_MAPPING.keys():
        print(lang)
        
    print("Cache Initialized")
    port = os.getenv("PORT", "8000")
    print("Translation Service Ready")
    print(f"Listening on Port {port}")
    yield

app = FastAPI(lifespan=lifespan)

class TranslateRequest(BaseModel):
    text: str
    source_language: str
    target_language: str

@app.get("/health")
async def health_check():
    model_name = os.getenv("MODEL_NAME", "facebook/nllb-200-distilled-600M")
    return {
        "status": "healthy",
        "model": model_name,
        "languages": list(LANGUAGE_MAPPING.keys()),
        "cache_entries": get_cache_size()
    }

@app.post("/translate")
async def translate_text(req: TranslateRequest):
    req_id = str(uuid.uuid4())[:8]
    start_time = time.time()
    
    try:
        print(f"\nRequest ID: {req_id}")
        print(f"Language: {req.source_language} -> {req.target_language}")
        print(f"Characters: {len(req.text) if req.text else 0}")
        
        translated_text, cache_hit = translate(req.text, req.source_language, req.target_language)
        
        end_time = time.time()
        elapsed_ms = int((end_time - start_time) * 1000)
        
        print(f"Cache: {'HIT' if cache_hit else 'MISS'}")
        print(f"Translation Time: {elapsed_ms} ms")
        
        return {"translated_text": translated_text}
    except Exception as e:
        print(f"Error [{req_id}]: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run("app:app", host="0.0.0.0", port=port)
