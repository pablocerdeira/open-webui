"""
Integração com Knowledge Bases externas (LlamaIndex compartilhado)
"""

import os
import httpx
import logging
from typing import List, Dict, Any, Optional

log = logging.getLogger(__name__)

EXTERNAL_KB_URL = os.getenv('LLAMAINDEX_SHARED_URL', 'http://10.10.10.10:5760')
INSTANCE_ID = os.getenv('INSTANCE_NAME', 'dev')
INSTANCE_TOKEN = os.getenv('LLAMAINDEX_INSTANCE_TOKEN', f'{INSTANCE_ID}_kb_access_token')
ENABLE_EXTERNAL = os.getenv('ENABLE_EXTERNAL_KNOWLEDGE_BASES', 'false').lower() == 'true'


async def fetch_external_kbs(user_token: Optional[str] = None) -> List[Dict[str, Any]]:
    """
    Buscar Knowledge Bases externas do LlamaIndex compartilhado
    
    Returns:
        List[Dict]: Lista de KBs no formato compatível com Open-WebUI
    """
    if not ENABLE_EXTERNAL:
        log.debug("Knowledge Bases externas desabilitadas")
        return []
    
    try:
        headers = {
            'X-Instance-ID': INSTANCE_ID,
            'X-Instance-Token': INSTANCE_TOKEN,
            'Content-Type': 'application/json'
        }
        
        # Se tiver token de usuário, incluir nos headers
        if user_token:
            headers['X-User-Token'] = user_token
            
        url = f"{EXTERNAL_KB_URL}/api/v1/knowledge"
        
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(url, headers=headers)
            response.raise_for_status()
            
            external_kbs = response.json()
            log.info(f"Obtidas {len(external_kbs)} Knowledge Bases externas")
            
            # As KBs já vêm no formato correto do nosso endpoint LlamaIndex
            return external_kbs
            
    except httpx.TimeoutException:
        log.warning("Timeout ao conectar com Knowledge Bases externas")
        return []
    except httpx.HTTPStatusError as e:
        log.warning(f"Erro HTTP ao buscar KBs externas: {e.response.status_code}")
        return []
    except Exception as e:
        log.error(f"Erro inesperado ao buscar KBs externas: {e}")
        return []


async def query_external_kb(kb_id: str, query: str, user_token: Optional[str] = None) -> Optional[Dict[str, Any]]:
    """
    Fazer query em uma Knowledge Base externa
    
    Args:
        kb_id: ID da Knowledge Base
        query: Query de pesquisa
        user_token: Token do usuário (opcional)
        
    Returns:
        Dict: Resultado da query ou None se falhar
    """
    if not ENABLE_EXTERNAL:
        return None
        
    try:
        headers = {
            'X-Instance-ID': INSTANCE_ID,
            'X-Instance-Token': INSTANCE_TOKEN,
            'Content-Type': 'application/json'
        }
        
        if user_token:
            headers['X-User-Token'] = user_token
            
        url = f"{EXTERNAL_KB_URL}/api/v1/knowledge/{kb_id}/query"
        payload = {
            "query": query,
            "top_k": 5
        }
        
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(url, headers=headers, json=payload)
            response.raise_for_status()
            
            result = response.json()
            log.info(f"Query externa executada com sucesso para KB {kb_id}")
            
            return result
            
    except httpx.TimeoutException:
        log.warning(f"Timeout ao fazer query na KB externa {kb_id}")
        return None
    except httpx.HTTPStatusError as e:
        log.warning(f"Erro HTTP ao fazer query na KB externa {kb_id}: {e.response.status_code}")
        return None
    except Exception as e:
        log.error(f"Erro inesperado ao fazer query na KB externa {kb_id}: {e}")
        return None


def is_external_kb(kb_id: str) -> bool:
    """
    Verificar se uma KB é externa baseado no ID
    
    Args:
        kb_id: ID da Knowledge Base
        
    Returns:
        bool: True se for KB externa
    """
    # KBs externas têm prefixo específico
    return kb_id.startswith('kb___')