# Guia: Como Obter Chaves API para Discovery Stack

Este guia mostra passo a passo como obter todas as chaves API necessárias para o arquivo `.env`.

## 📋 Sumário de Chaves Necessárias

| Chave | Serviço | Dificuldade | Tempo |
|-------|---------|-------------|-------|
| LIDARR_API_KEY | Lidarr | Fácil | 1 min |
| JELLYSEERR_API_KEY | Jellyseerr | Fácil | 1 min |
| SPOTIFY_CLIENT_ID | Spotify | Média | 5 min |
| SPOTIFY_CLIENT_SECRET | Spotify | Média | 5 min |
| LASTFM_API_KEY | LastFM | Fácil | 3 min |
| TRAKT_CLIENT_ID | Trakt | Média | 10 min |
| TRAKT_CLIENT_SECRET | Trakt | Média | 10 min |
| TRAKT_ACCESS_TOKEN | Trakt | Média | 10 min |

---

## 1️⃣ Lidarr API Key (Fácil - 1 min)

**Para:** Lidify (descoberta de música)

### Passos:

1. **Acesse o Lidarr:**
   ```
   http://192.168.31.5:8686
   ```

2. **Vá em Settings > General**
   - Menu lateral: Settings (ícone de engrenagem)
   - Aba: General

3. **Copie a API Key**
   - Procure pelo campo "API Key"
   - Clique no botão de copiar ou selecione a chave
   - Exemplo: `abc123def456ghi789jkl012mno345pq`

4. **Adicione ao .env:**
   ```bash
   LIDARR_API_KEY=abc123def456ghi789jkl012mno345pq
   ```

---

## 2️⃣ Jellyseerr API Key (Fácil - 1 min)

**Para:** ListSync (sincronização de watchlists)

### Passos:

1. **Acesse o Jellyseerr:**
   ```
   http://192.168.31.5:5055
   ```

2. **Faça login**
   - Primeiro acesso: crie uma conta admin

3. **Vá em Settings > General**
   - Menu lateral: Settings (ícone de engrenagem)
   - Aba: General

4. **Copie a API Key**
   - Procure pelo campo "API Key"
   - Clique em "Copy" ou copie manualmente
   - Exemplo: `xyz789abc456def123ghi789jkl012mno`

5. **Adicione ao .env:**
   ```bash
   JELLYSEERR_API_KEY=xyz789abc456def123ghi789jkl012mno
   ```

---

## 3️⃣ Spotify API (Média - 5 min)

**Para:** Lidify (descoberta de música via Spotify)

### Passos:

1. **Acesse o Spotify Developer Dashboard:**
   ```
   https://developer.spotify.com/dashboard
   ```

2. **Faça login com sua conta Spotify**
   - Use sua conta pessoal (não precisa de Premium para API)

3. **Crie um novo app:**
   - Clique no botão "Create App"
   - Ou "Create app" se já tiver apps

4. **Preencha os dados do app:**
   - **App name:** `Lidify Homelab` (ou o que preferir)
   - **App description:** `Music discovery for homelab`
   - **Redirect URI:** `http://localhost:3333/callback`
   - **Website:** (opcional) `http://homelab.local`

5. **Salve o app**
   - Clique em "Save"

6. **Copie as credenciais:**
   - **Client ID:** Visível na tela do app
     - Exemplo: `a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6`
   - **Client Secret:**
     - Clique em "Show client secret"
     - Exemplo: `z9y8x7w6v5u4t3s2r1q0p9o8n7m6l5k4`

7. **Adicione ao .env:**
   ```bash
   SPOTIFY_CLIENT_ID=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
   SPOTIFY_CLIENT_SECRET=z9y8x7w6v5u4t3s2r1q0p9o8n7m6l5k4
   ```

### ⚠️ Importante:
- A Redirect URI deve ser exatamente: `http://localhost:3333/callback`
- Não precisa de conta Premium para usar a API

---

## 4️⃣ LastFM API Key (Fácil - 3 min)

**Para:** Lidify (scrobbling e recomendações)

### Passos:

1. **Acesse o LastFM API:**
   ```
   https://www.last.fm/api/account/create
   ```

2. **Faça login ou crie uma conta**
   - É gratuito
   - Confirme o email

3. **Preencha o formulário de API:**
   - **Application name:** `Lidify Homelab`
   - **Application description:** `Music discovery for homelab`
   - **Homepage:** (opcional) `http://homelab.local`
   - **Application homepage URL:** (opcional) `http://homelab.local`

4. **Confirme e aceite os termos**
   - Clique em "Submit"

5. **Copie a API Key**
   - Será mostrada na próxima página
   - Exemplo: `b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7`

6. **Adicione ao .env:**
   ```bash
   LASTFM_API_KEY=b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7
   ```

### ⚠️ Nota:
- LastFM também fornece uma "Shared Secret", mas o Lidify só precisa da API Key
- Guarde a Secret se quiser expandir funcionalidades no futuro

---

## 5️⃣ Trakt API (Média - 10 min)

**Para:** ListSync (sincronização de watchlists Trakt)

### Passos:

1. **Acesse o Trakt:**
   ```
   https://trakt.tv/oauth/applications
   ```

2. **Faça login**
   - Crie uma conta se não tiver

3. **Clique em "Create New Application"**
   - Botão no final da página

4. **Preencha os dados do app:**
   - **Name:** `ListSync Homelab`
   - **Description:** `Sync watchlists to Jellyseerr`
   - **Redirect URI:** `http://localhost:8082/callback`
   - **Javascript Origins:** deixe em branco

5. **Clique em "Save App"**

6. **Copie as credenciais:**
   - **Client ID:** Visível na página do app
     - Exemplo: `c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8`
   - **Client Secret:** Clique em "Show secret"
     - Exemplo: `s8r7q6p5o4n3m2l1k0j9i8h7g6f5e4d3c`

7. **Gere o Access Token:**
   - **Opção A (via script):**
     ```bash
     # Substitua CLIENT_ID e CLIENT_SECRET pelos valores reais
     curl -X POST \
       "https://api.trakt.tv/oauth/token" \
       -H "Content-Type: application/json" \
       -d '{
         "client_id": "SEU_CLIENT_ID",
         "client_secret": "SEU_CLIENT_SECRET",
         "grant_type": "client_credentials",
         "redirect_uri": "http://localhost:8082/callback"
       }'
     ```

   - **Opção B (via Postman/Insomnia):**
     - Método: POST
     - URL: `https://api.trakt.tv/oauth/device/code`
     - Use suas credenciais

   - **Opção C (mais fácil - use o ListSync):**
     - Configure ListSync sem o token primeiro
     - O próprio ListSync vai pedir para autenticar
     - Siga as instruções na tela

8. **Adicione ao .env:**
   ```bash
   TRAKT_CLIENT_ID=c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8
   TRAKT_CLIENT_SECRET=s8r7q6p5o4n3m2l1k0j9i8h7g6f5e4d3c
   TRAKT_ACCESS_TOKEN=token_gerado_na_autenticacao
   ```

### ⚠️ Nota sobre Access Token:
Se não quiser gerar o token manualmente, deixe em branco por enquanto. O ListSync vai pedir para autenticar via browser quando você acessá-lo pela primeira vez.

---

## 6️⃣ IMDb Watchlist URL (Opcional - 2 min)

**Para:** ListSync (sincronização de listas IMDb)

### Passos:

1. **Acesse o IMDb:**
   ```
   https://www.imdb.com/
   ```

2. **Faça login e crie sua watchlist**
   - Adicione alguns filmes/séries à watchlist

3. **Encontre sua URL de watchlist:**
   - Vá para: Your Profile > Your Watchlist
   - Ou acesse diretamente: `https://www.imdb.com/user/urXXXXXXX/list/watchlist`
   - Copie a URL completa

4. **Exemplo:**
   ```
   https://www.imdb.com/user/ur12345678/list/watchlist
   ```

5. **Adicione ao .env:**
   ```bash
   IMDB_USER_LIST_URL=https://www.imdb.com/user/ur12345678/list/watchlist
   ```

---

## 7️⃣ Letterboxd Username (Opcional - 1 min)

**Para:** ListSync (sincronização de listas Letterboxd)

### Passos:

1. **Acesse o Letterboxd:**
   ```
   https://letterboxd.com/
   ```

2. **Faça login**
   - Crie uma conta se não tiver

3. **Copie seu username**
   - Vá ao seu perfil
   - O username está na URL: `https://letterboxd.com/SEU_USERNAME/`

4. **Adicione ao .env:**
   ```bash
   LETTERBOXD_USERNAME=seu_username_aqui
   ```

---

## 📝 Arquivo .env Final

Após obter todas as chaves, seu `.env` ficará assim:

```bash
# ============================================================================
# DISCOVERY STACK - ENVIRONMENT VARIABLES
# ============================================================================

# Spotify (para Lidify)
SPOTIFY_CLIENT_ID=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
SPOTIFY_CLIENT_SECRET=z9y8x7w6v5u4t3s2r1q0p9o8n7m6l5k4

# LastFM (para Lidify)
LASTFM_API_KEY=b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7

# Lidarr (para Lidify)
LIDARR_API_KEY=abc123def456ghi789jkl012mno345pq

# Jellyseerr (para ListSync)
JELLYSEERR_API_KEY=xyz789abc456def123ghi789jkl012mno

# Trakt (para ListSync)
TRAKT_CLIENT_ID=c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8
TRAKT_CLIENT_SECRET=s8r7q6p5o4n3m2l1k0j9i8h7g6f5e4d3c
TRAKT_ACCESS_TOKEN=

# IMDb (para ListSync) - Opcional
IMDB_USER_LIST_URL=https://www.imdb.com/user/ur12345678/list/watchlist

# Letterboxd (para ListSync) - Opcional
LETTERBOXD_USERNAME=seu_username
```

---

## 🚀 Ordem Recomendada

Para facilitar, obtenha as chaves nesta ordem:

1. ✅ **Lidarr API** - 1 min (precisa do Lidarr rodando)
2. ✅ **Jellyseerr API** - 1 min (precisa do Jellyseerr rodando)
3. ✅ **Spotify API** - 5 min
4. ✅ **LastFM API** - 3 min
5. ⏸️ **Trakt API** - 10 min (pode fazer depois)
6. ⏸️ **IMDb/Letterboxd** - Opcionais

---

## 💡 Dicas

### Chaves Obrigatórias vs Opcionais:

**Obrigatórias para funcionamento básico:**
- Nenhuma! O Discovery Stack funciona sem chaves externas

**Obrigatórias para funcionalidades específicas:**
- `LIDARR_API_KEY` - Para Lidify funcionar
- `JELLYSEERR_API_KEY` - Para ListSync funcionar

**Opcionais (mas recomendadas):**
- Spotify/LastFM - Para recomendações de música no Lidify
- Trakt/IMDb/Letterboxd - Para sincronização no ListSync

### Segurança:
- **Nunca** commit o arquivo `.env` no Git
- **Nunca** compartilhe suas chaves publicamente
- Mantenha o `.env.example` como template

### Rotatividade de Chaves:
- Spotify/LastFM/Trakt: não expiram
- Se precisar renovar, basta atualizar o `.env` e reiniciar o serviço:
  ```bash
  docker service update --force discovery_lidify
  ```

---

## 🔗 Links Úteis

- [Spotify Dashboard](https://developer.spotify.com/dashboard)
- [LastFM API](https://www.last.fm/api/account/create)
- [Trakt Apps](https://trakt.tv/oauth/applications)
- [Letterboxd](https://letterboxd.com/)
- [IMDb](https://www.imdb.com/)

---

**Tempo total estimado:** ~30 minutos (incluindo criação de contas)

**Dúvidas?** Consulte o README de cada serviço em `stacks/discovery-stack/README.md`
