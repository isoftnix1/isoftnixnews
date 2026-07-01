import os
from transformers import AutoModelForSeq2SeqLM, AutoTokenizer
import torch

_model = None
_tokenizer = None

def load_model():
    global _model, _tokenizer
    model_name = os.getenv("MODEL_NAME", "facebook/nllb-200-distilled-600M")
    
    print("Loading Translation Model...")
    print("Loading Tokenizer...")
    _tokenizer = AutoTokenizer.from_pretrained(model_name)
    
    print("Checking Local Model...")
    print("Loading Model...")
    _model = AutoModelForSeq2SeqLM.from_pretrained(model_name)
    
    if torch.cuda.is_available():
        _model = _model.to("cuda")
        
    print("Model Loaded Successfully")

def get_model():
    return _model

def get_tokenizer():
    return _tokenizer
