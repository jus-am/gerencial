#!/usr/bin/env bash
set -euo pipefail

[[ "${CODESPACES:-}" == "true" && "${CODESPACE_NAME:-}" =~ ^[a-z0-9-]+$ ]]
[[ "${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-}" == "app.github.dev" ]]

network=gerencial-homologacao-codespace
db=supabase_db_gerencial-2-homologacao-local
supabase=(npx --yes supabase@2.98.0)
if ! docker network inspect "$network" >/dev/null 2>&1; then
    docker network create -o com.docker.network.bridge.host_binding_ipv4=127.0.0.1 "$network" >/dev/null
fi
"${supabase[@]}" start --network-id "$network" >/dev/null 2>&1 +    || { printf '%s\n' 'Falha na inicialização do Supabase descartável.' >&2; exit 1; }

if [[ "$(docker exec "$db" psql -U postgres -d postgres -Atc "select to_regclass('public.perfis_usuarios') is null")" == "t" ]]; then
    node seguranca/preparar-banco-local.cjs | docker exec -i +        -e 'PGOPTIONS=-c gerencial.homologacao_local=sim' "$db" psql -U postgres -d postgres -v ON_ERROR_STOP=1 >/dev/null
fi

"${supabase[@]}" status -o json | node seguranca/preparar-acessos-codespace.cjs
if ! curl -fsS http://127.0.0.1:8081/ -o /dev/null 2>/dev/null; then
    nohup node seguranca/servir-local.cjs --codespace >/dev/null 2>&1 </dev/null &
fi
if ! docker inspect gerencial-preview-caddy >/dev/null 2>&1; then
    docker run -d --restart unless-stopped --network host --name gerencial-preview-caddy +        --read-only -v "$PWD/seguranca/Caddyfile:/etc/caddy/Caddyfile:ro" +        caddy:2.10.2-alpine >/dev/null
else
    docker start gerencial-preview-caddy >/dev/null
fi

curl --retry 10 --retry-connrefused --retry-delay 1 -fsS http://127.0.0.1:8080/ -o /dev/null
