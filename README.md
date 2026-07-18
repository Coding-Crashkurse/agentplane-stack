# agentplane-stack

Deployment artifacts for the [agentplane](https://github.com/Coding-Crashkurse/agentplane)
platform — run the whole stack (gateway, registry, runtime, portal UI,
low-code builder, identity) on your own infrastructure. Everything is pinned
to released images; upgrading = bumping tags.

Two installation paths:

| Path | For | Entry point |
|---|---|---|
| **Docker Compose** | single host, evaluation, small teams | [`compose/`](compose/) |
| **Helm chart** | Kubernetes, production self-hosting | [`helm/agentplane/`](helm/agentplane/) |

## Compose (single host)

```bash
cd compose
# dev/local (hosts on *.localhost):
docker compose -f compose.yaml --profile langfuse up -d --wait

# production (real domains + ACME TLS):
#   set APP_DOMAIN, API_DOMAIN, AUTH_DOMAIN, BUILDER_DOMAIN, TRACES_DOMAIN,
#   ACME_EMAIL in .env, then:
docker compose -f compose.yaml -f compose.prod.yaml --profile langfuse up -d
```

The compose file is the release-pinned copy of the agentplane repo's dev
stack (`deploy/compose/`) — same topology, no source builds.

## Helm (Kubernetes)

```bash
kubectl create namespace agentplane
kubectl -n agentplane create secret generic llm \
  --from-literal=OPENAI_API_KEY=sk-...

helm install agentplane ./helm/agentplane -n agentplane \
  --set hosts.app=app.example.com \
  --set hosts.api=api.example.com \
  --set hosts.auth=auth.example.com \
  --set hosts.builder=builder.example.com \
  --set llm.apiKeySecret=llm \
  --set runtime.secretKey="$(python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())')" \
  --set keycloak.adminPassword='...' \
  --set postgres.password='...'
```

What the chart deploys: agentgateway (edge: `/a2a`, `/mcp`, `/registry`,
`/runtime`; the `/v1` LLM egress stays cluster-internal), registry, runtime,
portal UI, builder (optional), plus **optional bundled** Keycloak (with the
demo realm import) and Postgres. One Ingress covers all hosts; TLS via your
ingress/cert-manager annotations (`ingress.annotations`, `ingress.tls`).

Notes that matter:

- **DNS/issuer reachability:** pods validate tokens against the issuer URL.
  With the bundled Keycloak that is `https://<hosts.auth>/...` — the cluster
  must resolve and reach it (public DNS or a CoreDNS rewrite to your ingress).
- **Bring your own IdP:** set `oidc.issuer` to your Entra ID/Okta/… issuer and
  `keycloak.enabled=false`. Your IdP must issue the `audience`, a roles claim
  (`oidc.rolesClaim`) containing `admin`/`builder`/`user`, and the groups/
  username claims — all claim paths are configurable.
- **Runtime is single-replica** (`strategy: Recreate`): serving state is
  per-process until multi-instance support lands. Keep `replicaCount.runtime: 1`.
- **Tracing:** set `tracing.otlpEndpoint` to an OTLP/HTTP collector. For
  Langfuse, deploy the official [Langfuse Helm chart](https://langfuse.com/self-hosting)
  plus an otel-collector using the config in
  [`compose/otel/otel-collector-langfuse.yaml`](compose/otel/otel-collector-langfuse.yaml)
  (it also filters infrastructure noise so traces show chat activity only).

## Hardening checklist (before real users)

- Rotate/replace every bootstrap credential: Keycloak admin, Postgres
  password, `runtime.secretKey` (generated, never a shared default),
  `runtime.registryClientSecret`.
- Disable the demo realm import (`keycloak.importRealm=false`) or remove the
  demo users (`demo-admin`/`demo-builder`/`demo-user`) from
  `helm/agentplane/files/agentplane-realm.json` first.
- TLS everywhere; never route the gateway's `/v1` (LLM egress) on the public
  ingress — it would be an open LLM proxy on your bill.
- Back up Postgres **and** the runtime secret key separately — resources are
  unusable without the key.
- Consider rate limits at your ingress on top of the gateway's per-instance
  token bucket.

## Versions in this release

| Component | Image |
|---|---|
| registry / runtime | `ghcr.io/coding-crashkurse/agentplane-{registry,runtime}:0.0.5` |
| portal UI | `ghcr.io/coding-crashkurse/agentplane-ui:0.2.0` |
| builder | `ghcr.io/coding-crashkurse/agentplane-builder:0.2.0` |
| agentgateway | `ghcr.io/agentgateway/agentgateway:0.8.2` (exact pin) |
| Keycloak / Postgres | `quay.io/keycloak/keycloak:26.0` / `postgres:16` |

## License

MIT
