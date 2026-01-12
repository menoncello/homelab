# Nginx Proxy Manager - Discovery Stack Configuration

Configuração completa de proxy hosts para todos os serviços da Discovery Stack.

## Tabela de Configuração

Use esta tabela para configurar os Proxy Hosts no Nginx Proxy Manager (http://192.168.31.5:81)

| Domínio | Forward Host/IP | Port | Cache | SSL |
|---------|-----------------|------|-------|-----|
| sonarr.menoncello.com | 192.168.31.5 | 8989 | ❌ | ✅ |
| radarr.menoncello.com | 192.168.31.5 | 7878 | ❌ | ✅ |
| lidarr.menoncello.com | 192.168.31.5 | 8686 | ❌ | ✅ |
| listenarr.menoncello.com | 192.168.31.5 | 8988 | ❌ | ✅ |
| prowlarr.menoncello.com | 192.168.31.5 | 9696 | ❌ | ✅ |
| bazarr.menoncello.com | 192.168.31.5 | 6767 | ❌ | ✅ |
| qbittorrent.menoncello.com | 192.168.31.5 | 9091 | ❌ | ✅ |
| jellyseerr.menoncello.com | 192.168.31.5 | 5055 | ❌ | ✅ |
| lidify.menoncelello.com | 192.168.31.5 | 3333 | ❌ | ✅ |
| listsync.menoncello.com | 192.168.31.6 | 8082 | ❌ | ✅ |
| movary.menoncello.com | 192.168.31.5 | 5056 | ❌ | ✅ |

## Port Mapping Reference

| Service | Internal Port | External Port | Runs On |
|---------|---------------|---------------|---------|
| Sonarr | 8989 | 8989 | pop-os (192.168.31.5) |
| Radarr | 7878 | 7878 | pop-os (192.168.31.5) |
| Lidarr | 8686 | 8686 | pop-os (192.168.31.5) |
| Listenarr | 5000 | 8988 | pop-os (192.168.31.5) |
| Prowlarr | 9696 | 9696 | pop-os (192.168.31.5) |
| Bazarr | 6767 | 6767 | pop-os (192.168.31.5) |
| qBittorrent | 9091 | 9091 | pop-os (192.168.31.5) |
| qBittorrent | 6881 | 6881 | pop-os (192.168.31.5) |
| Jellyseerr | 5055 | 5055 | pop-os (192.168.31.5) |
| Lidify | 5000 | 3333 | pop-os (192.168.31.5) |
| ListSync | 3222 | 8082 | Xeon01 (192.168.31.6) |
| Movary | 8080 | 5056 | pop-os (192.168.31.5) |

## Instruções de Configuração

### 1. Acesse o Nginx Proxy Manager

```
http://192.168.31.5:81
```

### 2. Para cada serviço:

1. Clique em **Proxy Hosts** > **Add Proxy Host**
2. Preencha:
   - **Domain Names**: `nome.menoncello.com`
   - **Scheme**: `http`
   - **Forward Hostname/IP**: `192.168.31.5` ou `192.168.31.6` (ver tabela)
   - **Forward Port**: porta externa (ver tabela)
3. Aba **SSL**:
   - Enable SSL: ✅
   - Force SSL: ✅
   - HTTP/2: ✅
   - SSL Certificate: Let's Encrypt
4. Clique em **Save**

### 3. Serviços no Xeon01 (192.168.31.6)

Apenas o **ListSync** roda no Xeon01. Todos os outros rodam no pop-os (192.168.31.5).

## Correções de Porta Aplicadas

Durante o troubleshooting, as seguintes correções foram aplicadas:

| Service | Problema | Solução |
|---------|----------|---------|
| Lidify | target: 3333 | target: 5000 (porta interna) |
| ListSync | target: 8082 | target: 3222 (porta interna) |
| Movary | target: 80 | target: 8080 (porta interna) |

## Verificação

Após configurar todos os proxy hosts, verifique:

```bash
# Teste cada domínio
curl -I https://sonarr.menoncello.com
curl -I https://radarr.menoncello.com
curl -I https://lidarr.menoncello.com
curl -I https://listenarr.menoncello.com
curl -I https://prowlarr.menoncello.com
curl -I https://bazarr.menoncello.com
curl -I https://jellyseerr.menoncello.com
curl -I https://lidify.menoncello.com
curl -I https://listsync.menoncello.com
curl -I https://movary.menoncello.com
```

Todos devem retornar `HTTP/1.1 200 OK` ou redirect para setup page.

## URLs Finais

Após configuração do proxy, acesse:

- **Sonarr**: https://sonarr.menoncello.com
- **Radarr**: https://radarr.menoncello.com
- **Lidarr**: https://lidarr.menoncello.com
- **Listenarr**: https://listenarr.menoncello.com
- **Prowlarr**: https://prowlarr.menoncello.com
- **Bazarr**: https://bazarr.menoncello.com
- **qBittorrent**: https://qbittorrent.menoncello.com
- **Jellyseerr**: https://jellyseerr.menoncello.com
- **Lidify**: https://lidify.menoncello.com
- **ListSync**: https://listsync.menoncello.com
- **Movary**: https://movary.menoncello.com

## Próximos Passos

1. Configure os Proxy Hosts conforme tabela acima
2. Configure o arquivo `.env` com as chaves API necessárias (veja API_KEYS_GUIDE.md)
3. Configure cada serviço individualmente (veja README.md)

---

**Data**: 2026-01-11
**Stack**: Discovery Stack (11 serviços)
**Status**: Todos os serviços rodando
