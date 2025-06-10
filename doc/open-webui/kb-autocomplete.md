Open WebUI KB Autocomplete Documentation
=========================================

Overview
--------

Open WebUI possui um recurso embutido que permite aos usuários digitar o caractere `#` em um prompt de pesquisa para ativar a exibição de uma lista de Knowledge Bases (Bases de Conhecimento) disponíveis para consulta. Este mecanismo facilita a inclusão de conteúdos contextualizados durante o uso de modelos de linguagem grandes (LLMs) com suporte a Retrieval Augmented Generation (RAG).

Como Funciona
--------------

- O frontend mantém uma store chamada `knowledge` que armazena a lista atualizada das KBs disponíveis para o usuário autenticado.
- Esta lista é obtida via API (endpoints REST em `/api/v1/knowledge`), as quais devolvem as bases disponíveis de acordo com as permissões do usuário.
- O componente Reactivo no Svelte para a seleção das KBs é o `src/lib/components/workspace/Models/Knowledge/Selector.svelte`, que:
  - Combina KBs atuais com coleções legadas (legacy) para compor a lista exibida.
  - Utiliza Fuse.js para permitir busca dinâmica baseada em nome e descrição das KBs.
  - Permite o usuário pesquisar e filtrar bases com UI responsiva.
- Ao detectar o `#` no prompt, este componente é acionado para mostrar a lista e o usuário pode escolher a KB desejada para adicionar ao prompt.

Backend
--------

- O backend oferece endpoint REST `/api/v1/knowledge` (e caminhos derivados) para fornecer:
  - Listagem das knowledge bases acessíveis 
  - Detalhes e arquivos associados a cada base
  - Operações CRUD para criação, atualização e exclusão
- As APIs filtram as KBs por permissões de acesso do usuário, garantindo segurança.
- Os arquivos associados às KBs são retornados junto dos metadados para compor o contexto completo.

Efeito na Pesquisa Submetida ao LLM
-----------------------------------

- Quando uma ou mais knowledge bases são citadas no prompt via `#`, a pesquisa que é enviada ao LLM inclui documentos dessas bases.
- Isso permite o mecanismo RAG buscar respostas com base no conteúdo concreto armazenado nessas KBs, incrementando a qualidade e a relevância da resposta gerada.
- O backend integra esse fluxo, buscando os documentos relacionados e incorporando ao contexto que vai ao modelo.

Benefícios
---------

- Integração simples e intuitiva para uso de conteúdo dinâmico e contextual nas interações com o LLM
- Controle de acesso robusto para permitir que somente KBs autorizadas sejam exibidas e usadas
- Arquitetura modular e extensível para fácil manutenção e evolução do sistema

Referências
----------

- Frontend Component: `src/lib/components/workspace/Models/Knowledge/Selector.svelte`
- Store Svelte: `src/lib/stores/index.ts` exporta a store `knowledge`
- Backend Router: `backend/open_webui/routers/knowledge.py` com endpoints `/api/v1/knowledge`
- API Client Frontend: `src/lib/apis/knowledge/index.ts`

Detalhes Técnicos
-----------------

### Frontend

- Componente principal: `src/lib/components/workspace/Models/Knowledge/Selector.svelte` (linhas 1-90)
  - Usa Fuse.js para busca rápida entre itens da lista
  - Combina conhecimento atual (`knowledge` store) e coleções legadas para exibição
  - Expõe evento `select` na escolha de uma KB
- Store Svelte: `knowledge` exportada por `src/lib/stores/index.ts`
- API Client no frontend: funções em `src/lib/apis/knowledge/index.ts` chamadas para endpoints REST `/api/v1/knowledge`

### Backend

- Arquivo: `backend/open_webui/routers/knowledge.py`
- Função para listar KBs (com arquivos vinculados): `get_knowledge_list(user=Depends(get_verified_user))` (aproximadamente linha 90-150)
- Função para criar KB: `create_new_knowledge` (linha ~152 em diante)
- As rotas REST base para CRUD ficam sob `/api/v1/knowledge`

Incluir KBs Externas e Simular Comportamento
--------------------------------------------

Se você mantém um RAG externo com suas próprias knowledge bases, pode integrar com Open-WebUI para que estas KBs externas estejam disponíveis na seleção com `#`:

1. Desenvolva um serviço que registre e exponha estas KBs externas via um endpoint REST no padrão esperado, por exemplo `/api/v1/knowledge` do Open-WebUI.
2. Implemente a sincronização das KBs externas para alimentar a store `knowledge` no frontend, similar ao que `getKnowledgeBases` faz.
3. Ajuste o componente `Selector.svelte` ou crie um wrapper que incorpore essas KBs externas no dropdown.
4. No backend, garanta o controle de acesso e filtragem baseado nos perfis de usuário.
5. Ao enviar uma pesquisa ao LLM, capture as KBs selecionadas pelo usuário e modifique o contexto para incluir pedaços ou documentos dessas KBs externas.

Dessa forma, seus usuários poderão interagir com todas as KBs — internas e externas — por meio da interface padrão do Open-WebUI, usando o `#` para autocompletar e selecionar as bases, mantendo uma experiência unificada.

Com essa integração, você aproveita o front-end rico do Open-WebUI e deixa seu RAG externo responsável por manter/atualizar os dados e índices, garantindo extensibilidade e flexibilidade.

Se desejar posso ajudar a detalhar algum desses passos ou estruturar código de exemplo para a API de publicação das KBs para o Open-WebUI.