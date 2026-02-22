# Moltbot — Personal AI Assistant on Cloudflare

A personal [OpenClaw](https://github.com/openclaw/openclaw) AI assistant running in a [Cloudflare Sandbox](https://developers.cloudflare.com/sandbox/) container. Fork of [cloudflare/moltworker](https://github.com/cloudflare/moltworker).

## Current Configuration

| Feature | Status |
|---------|--------|
| AI Provider | OpenAI (gpt-5.2) |
| Chat Channel | Telegram |
| Persistent Storage | R2 (auto-backup every 30s) |
| Authentication | Cloudflare Access + gateway token + device pairing |
| Browser Automation | CDP via Browser Rendering |
| Container Sleep | Configured via `SANDBOX_SLEEP_AFTER` |
| ClawHub Skills | 7 installed (see below) |

### Installed Skills

| Skill | Description |
|-------|-------------|
| `pskoett/self-improving-agent` | Self-improving agent loop |
| `arun-8687/tavily-search` | Web search via Tavily |
| `oswalpalash/ontology` | Ontology/knowledge graph |
| `biostartechnology/humanizer` | Text humanization |
| `steipete/openai-whisper` | Audio transcription |
| `NicholasSpisak/clawddocs` | Documentation lookup |
| `steipete/clawdhub` | ClawHub integration |

## Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/) v22+
- [Cloudflare Workers Paid plan](https://www.cloudflare.com/plans/developer-platform/) ($5/month)
- An [OpenAI API key](https://platform.openai.com/api-keys)

### 1. Clone and Install

```bash
git clone https://github.com/weilun-tann/moltworker.git
cd moltworker
npm install
```

### 2. Configure Secrets

Set the required secrets via `wrangler secret put <NAME>`:

```bash
# AI Provider (required — at least one)
npx wrangler secret put OPENAI_API_KEY

# Gateway token (required — generate with: openssl rand -hex 32)
npx wrangler secret put MOLTBOT_GATEWAY_TOKEN

# Cloudflare Access (required for admin UI)
npx wrangler secret put CF_ACCESS_TEAM_DOMAIN   # e.g. "myteam.cloudflareaccess.com"
npx wrangler secret put CF_ACCESS_AUD           # Application Audience tag

# R2 persistent storage (recommended)
npx wrangler secret put R2_ACCESS_KEY_ID
npx wrangler secret put R2_SECRET_ACCESS_KEY
npx wrangler secret put CF_ACCOUNT_ID
```

**Optional secrets:**

```bash
# Telegram bot
npx wrangler secret put TELEGRAM_BOT_TOKEN
npx wrangler secret put TELEGRAM_DM_POLICY      # "pairing" (default) or "open"

# Browser automation (CDP)
npx wrangler secret put CDP_SECRET               # shared secret for /cdp endpoint
npx wrangler secret put WORKER_URL               # e.g. "https://moltbot-sandbox.your-subdomain.workers.dev"

# Container sleep (saves cost when idle)
npx wrangler secret put SANDBOX_SLEEP_AFTER      # e.g. "10m", "1h", or "never"
```

### 3. Deploy

If your machine uses **podman** instead of Docker, use the included shim:

```bash
# Podman users only — strips unsupported --provenance flag
export PATH="/tmp/docker-shim:$PATH"
export WRANGLER_DOCKER_BIN=/tmp/docker-shim/docker
ln -sf "$(pwd)/docker-shim.sh" /tmp/docker-shim/docker
```

Then deploy:

```bash
npm run deploy
```

### 4. First-Time Setup

1. Visit `https://your-worker.workers.dev/_admin/` and authenticate via Cloudflare Access
2. The gateway takes ~60-90 seconds on first start
3. Pair your device when prompted
4. Access the Control UI at `https://your-worker.workers.dev/?token=YOUR_GATEWAY_TOKEN`

## Architecture

```
Browser / Telegram / CLI
        │
        ▼
  Cloudflare Access (auth)
        │
        ▼
  Hono Worker (index.ts)
    ├── /_admin/     → Admin UI (device management)
    ├── /api/*       → REST API (devices, storage, restart)
    ├── /cdp/*       → CDP shim (browser automation)
    └── /*           → Proxy to OpenClaw gateway (port 18789)
        │
        ▼
  Cloudflare Sandbox Container
    ├── start-openclaw.sh  → R2 restore → onboard → patch → gateway
    ├── openclaw gateway   → AI agent runtime
    └── rclone sync loop   → R2 backup every 30s
```

## Key Files

| File | Purpose |
|------|---------|
| `src/index.ts` | Worker entry point, routing, proxy |
| `src/gateway/process.ts` | Gateway lifecycle (start, wait, restart) |
| `src/gateway/env.ts` | Environment variable mapping to container |
| `start-openclaw.sh` | Container startup script (R2 restore, config patch, gateway start) |
| `Dockerfile` | Container image (Node 22, OpenClaw, rclone) |
| `wrangler.jsonc` | Worker + container configuration |
| `clawhub-skills.json` | ClawHub skill manifest |
| `docker-shim.sh` | Podman compatibility wrapper |

## Troubleshooting

**`ProcessExitedBeforeReadyError: Process exited with code 1`**
The config has a validation error. Check `npx wrangler tail --format json` for stderr. Common cause: stale R2 config missing `baseUrl` on a provider entry. Fix: delete the stale config with `npx wrangler r2 object delete moltbot-data/openclaw/openclaw.json --remote` and redeploy.

**Gateway stuck on "Loading devices..."**
Wait ~90 seconds for the container to start. If it persists, check the tail logs.

**Config changes not applying**
Edit the `# Build cache bust:` comment in `Dockerfile` and redeploy to force a fresh image.

**Podman build fails with `--provenance` error**
Use the docker-shim.sh wrapper (see Deploy section above).

## Cost Estimate (~24/7 uptime)

| Resource | Approx. Cost |
|----------|-------------|
| Memory (4 GiB) | ~$26/mo |
| CPU (~10% utilization) | ~$2/mo |
| Disk (8 GB) | ~$1.50/mo |
| Workers Paid plan | $5/mo |
| **Total** | **~$34.50/mo** |

Set `SANDBOX_SLEEP_AFTER` to reduce costs (e.g., `10m` → container sleeps after 10 min idle).

## Links

- [OpenClaw](https://github.com/openclaw/openclaw) — the AI assistant framework
- [Cloudflare Sandbox Docs](https://developers.cloudflare.com/sandbox/)
- [Upstream repo](https://github.com/cloudflare/moltworker)
