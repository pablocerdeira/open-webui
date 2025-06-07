#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR" || exit

# Add conditional Playwright browser installation
if [[ "${WEB_LOADER_ENGINE,,}" == "playwright" ]]; then
    if [[ -z "${PLAYWRIGHT_WS_URL}" ]]; then
        echo "Installing Playwright browsers..."
        playwright install chromium
        playwright install-deps chromium
    fi

    python -c "import nltk; nltk.download('punkt_tab')"
fi

KEY_FILE=.webui_secret_key

PORT="${PORT:-8080}"
HOST="${HOST:-0.0.0.0}"
if test "$WEBUI_SECRET_KEY $WEBUI_JWT_SECRET_KEY" = " "; then
  echo "Loading WEBUI_SECRET_KEY from file, not provided as an environment variable."

  if ! [ -e "$KEY_FILE" ]; then
    echo "Generating WEBUI_SECRET_KEY"
    # Generate a random value to use as a WEBUI_SECRET_KEY in case the user didn't provide one.
    echo $(head -c 12 /dev/random | base64) > "$KEY_FILE"
  fi

  echo "Loading WEBUI_SECRET_KEY from $KEY_FILE"
  WEBUI_SECRET_KEY=$(cat "$KEY_FILE")
fi

if [[ "${USE_OLLAMA_DOCKER,,}" == "true" ]]; then
    echo "USE_OLLAMA is set to true, starting ollama serve."
    ollama serve &
fi

if [[ "${USE_CUDA_DOCKER,,}" == "true" ]]; then
  echo "CUDA is enabled, appending LD_LIBRARY_PATH to include torch/cudnn & cublas libraries."
  export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/lib/python3.11/site-packages/torch/lib:/usr/local/lib/python3.11/site-packages/nvidia/cudnn/lib"
fi

# =============================================================================
# OTIMIZAÇÃO: Download inteligente de modelos no primeiro uso
# =============================================================================

# Função para download otimizado de modelos
download_models_if_needed() {
    local MODEL_CACHE_DIR="/app/backend/data/cache"
    local FIRST_RUN_MARKER="$MODEL_CACHE_DIR/.models_downloaded"
    
    # Verifica se já baixou os modelos
    if [ -f "$FIRST_RUN_MARKER" ]; then
        echo "✅ Modelos já foram baixados anteriormente, pulando download."
        return 0
    fi
    
    echo "🚀 PRIMEIRA EXECUÇÃO: Baixando modelos necessários..."
    echo "   Isso pode levar alguns minutos, mas será feito apenas uma vez."
    
    # Variáveis de ambiente para modelos (com defaults)
    USE_EMBEDDING_MODEL="${USE_EMBEDDING_MODEL:-sentence-transformers/all-MiniLM-L6-v2}"
    WHISPER_MODEL="${WHISPER_MODEL:-base}"
    TIKTOKEN_ENCODING_NAME="${TIKTOKEN_ENCODING_NAME:-cl100k_base}"
    
    # Download do modelo de embedding
    echo "📥 Baixando modelo de embedding: $USE_EMBEDDING_MODEL"
    python -c "
import sys
try:
    from sentence_transformers import SentenceTransformer
    print('Baixando $USE_EMBEDDING_MODEL...')
    model = SentenceTransformer('$USE_EMBEDDING_MODEL', device='cpu')
    print('✅ Modelo de embedding baixado com sucesso!')
except Exception as e:
    print(f'⚠️ Erro ao baixar modelo de embedding: {e}')
    sys.exit(1)
" || echo "⚠️ Falha no download do modelo de embedding, continuando..."
    
    # Download do modelo Whisper
    echo "📥 Baixando modelo Whisper: $WHISPER_MODEL"
    python -c "
import sys
try:
    from faster_whisper import WhisperModel
    print('Baixando Whisper $WHISPER_MODEL...')
    model = WhisperModel('$WHISPER_MODEL', device='cpu', compute_type='int8', download_root='$MODEL_CACHE_DIR/whisper/models')
    print('✅ Modelo Whisper baixado com sucesso!')
except Exception as e:
    print(f'⚠️ Erro ao baixar modelo Whisper: {e}')
    sys.exit(1)
" || echo "⚠️ Falha no download do Whisper, continuando..."
    
    # Preparar cache do tiktoken
    echo "📥 Preparando cache tiktoken: $TIKTOKEN_ENCODING_NAME"
    python -c "
import sys
try:
    import tiktoken
    print('Carregando encoding $TIKTOKEN_ENCODING_NAME...')
    encoding = tiktoken.get_encoding('$TIKTOKEN_ENCODING_NAME')
    print('✅ TikToken cache preparado!')
except Exception as e:
    print(f'⚠️ Erro ao preparar tiktoken: {e}')
    sys.exit(1)
" || echo "⚠️ Falha no tiktoken, continuando..."
    
    # Marcar como concluído
    touch "$FIRST_RUN_MARKER"
    echo "✅ Todos os modelos foram baixados e cached! Próximas execuções serão mais rápidas."
}

# Executar download de modelos se necessário (em background para não bloquear)
echo "🔍 Verificando necessidade de download de modelos..."
download_models_if_needed &
DOWNLOAD_PID=$!

# Check if SPACE_ID is set, if so, configure for space
if [ -n "$SPACE_ID" ]; then
  echo "Configuring for HuggingFace Space deployment"
  if [ -n "$ADMIN_USER_EMAIL" ] && [ -n "$ADMIN_USER_PASSWORD" ]; then
    echo "Admin user configured, creating"
    WEBUI_SECRET_KEY="$WEBUI_SECRET_KEY" uvicorn open_webui.main:app --host "$HOST" --port "$PORT" --forwarded-allow-ips '*' &
    webui_pid=$!
    echo "Waiting for webui to start..."
    while ! curl -s http://localhost:8080/health > /dev/null; do
      sleep 1
    done
    echo "Creating admin user..."
    curl \
      -X POST "http://localhost:8080/api/v1/auths/signup" \
      -H "accept: application/json" \
      -H "Content-Type: application/json" \
      -d "{ \"email\": \"${ADMIN_USER_EMAIL}\", \"password\": \"${ADMIN_USER_PASSWORD}\", \"name\": \"Admin\" }"
    echo "Shutting down webui..."
    kill $webui_pid
  fi

  export WEBUI_URL=${SPACE_HOST}
fi

PYTHON_CMD=$(command -v python3 || command -v python)

WEBUI_SECRET_KEY="$WEBUI_SECRET_KEY" exec "$PYTHON_CMD" -m uvicorn open_webui.main:app --host "$HOST" --port "$PORT" --forwarded-allow-ips '*' --workers "${UVICORN_WORKERS:-1}"
