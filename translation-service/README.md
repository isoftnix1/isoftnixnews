# Translation Service

A production-ready Python FastAPI microservice that uses the Meta NLLB-200 model to translate news content, explicitly built for English to Hindi translations.

## Project Architecture

This service works in tandem with the Node.js backend. The Node server issues translation requests to this service which utilizes a lightweight in-memory cache to store translations before invoking the `facebook/nllb-200-distilled-600M` model.

**Folder Structure**:
```
translation-service/
├── app.py                     # Main FastAPI server and HTTP routing
├── Dockerfile                 # Production Docker configuration
├── requirements.txt           # Python dependencies
├── .env.example               # Example environment variables
└── translator/
    ├── __init__.py
    ├── model.py               # Hugging Face model loading and storage
    ├── translator.py          # AI translation logic and data validation
    ├── cache.py               # In-memory translation caching
    └── language_mapper.py     # NLLB language code mappings
```

## Setup & Installation

### Python Setup
1. Create a virtual environment:
   ```bash
   python -m venv venv
   ```
2. Activate the virtual environment:
   - Linux/macOS: `source venv/bin/activate`
   - Windows: `.\venv\Scripts\activate`
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Copy `.env.example` to `.env` and set variables:
   ```bash
   PORT=8000
   MODEL_NAME=facebook/nllb-200-distilled-600M
   ```

### Running the Translation Service
Execute the server using Uvicorn:
```bash
uvicorn app:app --host 0.0.0.0 --port 8000
```
**Expected Startup Logs**:
```text
Loading Translation Model...
Loading Tokenizer...
Checking Local Model...
Loading Model...
Model Loaded Successfully
Supported Languages:
en
hi
Cache Initialized
Translation Service Ready
Listening on Port 8000
```

## Running the Node Backend
1. Go to the `backend/` directory.
2. Ensure `TRANSLATION_SERVICE_URL=http://localhost:8000` is set in your `.env`.
3. Start the server: `npm run dev` or `node server.js`.
4. Check the logs to verify the health check passes (`Translation Service available. Translation enabled.`).

## Docker Deployment
1. Build the Docker image:
   ```bash
   docker build -t translation-service .
   ```
2. Run the container independently:
   ```bash
   docker run -p 8000:8000 -e PORT=8000 translation-service
   ```

## Testing Translations
### Verify with Postman or cURL
```bash
curl -X POST http://localhost:8000/translate \
-H "Content-Type: application/json" \
-d '{"text": "India won the match.", "source_language": "en", "target_language": "hi"}'
```

### How to test in Flutter
1. Run the Flutter application.
2. In the `AppBar`, open the language selector.
3. Select **Hindi**.
4. The **Home Screen** will fetch news articles from the Node backend, sending `?lang=hi`.
5. The Node backend intercepts this, sends the `title` and `short_description` to the Python service.
6. Tap on a news article to view its details. The full `content` is translated and displayed on the **News Detail Screen**.
7. Close the app and reopen it to verify SharedPreferences successfully reloads Hindi.

### Common Troubleshooting
- **Node backend prints "Translation Service Unhealthy"**: Ensure the Python service is running on the correct port and `TRANSLATION_SERVICE_URL` exactly matches.
- **Out of Memory (OOM) Errors**: The NLLB-200 model requires sufficient RAM (at least ~2GB free). Ensure your host or Docker container limits are set appropriately.
- **Translation Timeout**: The Node service implements a strict 10s timeout. If translation takes longer, it will fail gracefully and return English. Check the Python console logs for translation durations.
