
# PRD. Agent‑First Distributed Dev

## 1) Summary
A desktop + headless system built **on Radicle** that provides a **local‑first, server‑optional** development workflow. Radicle handles identities, Git/COB replication, and patch/issue flows. Our app adds:
- **Reproducible runners** (Nix first; containers; optional Bazel/MicroVM/WASM).
- **Durable tasks/issues** as Radicle COBs with **periodic checkpoints**, not keystroke spam.
- **Realtime sessions** via WebRTC; squashed to session branches for review on Radicle.
- **Artifacts**: binaries to S3‑compatible storage; manifests to IPFS; CIDs recorded in tasks.
- **Agents** (post‑MVP) operating under **capability policies**, with test‑gated patches and signed provenance.

> Radicle provides the P2P Git/COB substrate and CI broker plumbing; we build the agentic, reproducible, artifact‑aware layer on top.

## 2) Product Goals
- **Local‑first**: Work offline; converge when peers meet.
- **Deterministic compute**: Identical builds across machines (Nix/containers).
- **Auditability**: Signed actions, reproducible runs, provenance attached to artifacts.
- **Agent safety (post‑MVP)**: Propose‑only by default; gated by tests and policy.

## 3) Non‑Goals
- Becoming a full IDE. We provide a focused realtime session editor only.
- Replacing public forges for teams that want them; we interoperate.

## 4) Users
- Indie devs; small/medium teams; automation‑heavy projects; headless build nodes.

## 5) Core Use Cases
1. **P2P clone & sync** of code + COBs; offline edits converge.
2. **Run CI locally/headless** with Nix; publish artifacts (S3) + manifests (IPFS).
3. **Realtime triage/coding** on a **session branch** with WebRTC; squash to patch.
4. **(Post‑MVP)** “Address with agent”: agent claims a task, proposes a patch, runs tests, and publishes artifacts with provenance.

## 6) Requirements

### 6.1 Functional — MVP (Must)
- **Radicle integration** (CLI adapter): open project, fetch/push patches, read/write COBs.
- **Task COB** schema (v1) and **checkpointing** from CRDT comments.
- **Nix runner** (devshell + `nix build`) and **rootless container runner**.
- **Artifact storage**: S3 for binaries; IPFS for manifests; link CIDs/URLs in COBs.
- **Headless mode**: rendezvous/relay (for peers), S3 uploader, IPFS pinning, runner pool.
- **Policy engine**: per‑repo capabilities; no secrets in repo.

### 6.2 Functional — Post‑MVP (Should/Could)
- Agents: local (Ollama), remote (OpenAI/Anthropic), peer‑assisted.
- Bazel runner; MicroVM (Firecracker) runner; WASM runner.
- Multi‑agent scheduling and leases; provenance (in‑toto‑like) with signatures.
- Git‑notes export of pointers for Git‑native visibility.

### 6.3 Non‑Functional
- Offline‑first; converge < 60s on reconnect.
- Determinism: same inputs → same outputs.
- Security: signed ops, capability gating, sandboxed execution.
- Performance: LAN clone speeds; artifact fetch p95 < 3s for 100MB (from S3).

## 7) System Design

### 7.1 Data boundaries
- **CRDT (Automerge/Y‑CRDT)**: high‑frequency comments and live buffers (local & ephemeral).
- **COBs (Radicle)**: durable tasks/issues/patch reviews via **periodic snapshots**.
- **Git**: code; session branches for squashed realtime edits.

### 7.2 Realtime transport
- **WebRTC data channels** (ICE + STUN/TURN). Checkpoint to Git; announce the session via a COB pointer.

### 7.3 Anchors
- **Primary**: AST‑anchored symbol path + subtree digest (tree‑sitter/LSP).
- **Fallbacks**: range + diff‑context; **detached** if mapping fails.

### 7.4 Runners & artifacts
- Nix and container runners (MVP); artifacts to **S3**; manifests to **IPFS**; provenance attached; links stored in COBs.

### 7.5 Agent (post‑MVP)
- Backends: Local/Remote/Peer‑assisted.  
- Key management: OS keychain or age‑encrypted file; no replication.  
- Safety: propose‑only; compile/test gates; self‑review; rollback on thresholds.  
- Context: code/semantic index + graph; retrieval‑based prompt packing.

## 8) UX Flows
- Share repo → peer clones via Radicle → COBs sync.  
- Start realtime session → WebRTC room → work → **Squash to patch** → review → merge.  
- Build → S3 upload + IPFS manifest → link into Task COB.  
- (Post‑MVP) Address with agent → session branch → test‑gated patch → artifacts/provenance attached.

## 9) KPIs
- p50 time to first clone via Radicle.  
- Determinism rate across nodes (same input → same output).  
- Artifact fetch p95 from S3.  
- (Post‑MVP) Agent patch acceptance rate and rollback incidence.

## 10) Release Criteria (MVP)
- Two NATed peers sync code & COBs via Radicle and can collaborate offline/online.  
- CI runs reproducibly (Nix) and publishes artifacts to S3 + manifests to IPFS; links appear in tasks.  
- Realtime session works via WebRTC; checkpoint to patch; human review & merge.

# Build Plan

## Principles
- **Durable via Radicle; ephemeral via CRDT/WebRTC.**
- **No secret replication.** Capabilities only.  
- **Reproducible by default.** Nix/container first.

## Repo layout
```
/apps
  /desktop
  /headless
/crates
  /core              # identities, caps, policy, config
  /rad-adapter       # CLI adapter; later RPC
  /crdt              # Automerge store + anchor mapping
  /realtime          # WebRTC signaling + Y-CRDT integration
  /runner-nix
  /runner-container
  /ipfs
  /s3                # S3 client (MinIO-compatible)
  /provenance        # attestation (post-MVP)
  /agent             # agent runtime (post-MVP)
  /index             # symbol/semantic indexes
/docs
/flake.nix
```

## Config (examples)

`config.toml`
```toml
[storage]
artifacts = "s3"     # s3|p2p
manifests = "ipfs"   # ipfs|s3

[s3]
endpoint = "https://r2.example.com"
bucket   = "artifacts"
region   = "auto"
signing  = "env"     # env|keychain|age

[ipfs]
api = "http://127.0.0.1:5001"
pin = true

[realtime]
stun = ["stun:stun.l.google.com:19302"]
turn = []            # optional TURN creds
checkpoint_seconds = 120

[policy]
agent_propose_only = true
require_tests_pass = true
max_edit_radius = 400
```

`agent.toml` (post‑MVP)
```toml
[backend]
mode = "local"       # local|remote|peer

[local]
ollama_url = "http://127.0.0.1:11434"
model = "qwen2.5-coder:14b"

[remote]
provider = "anthropic"   # or "openai"
key_source = "keychain"  # keychain|env|age
model = "claude-3.5-sonnet"

[peer]
min_params = 7_000_000_000
```

## Milestones

### M0 — Skeleton & Dev Env
- Nix flake (Rust/Tauri), workspace, `xtask`.
- `rad-adapter` (CLI): open project, fetch/push, list/write COBs.
- S3 & IPFS clients (smoke tests).

### M1 — **MVP Core (no agents)**
- **Task COB v1**: create/update/close; checkpoint CRDT → COB (manual + periodic).  
- **CRDT comments**: local store; anchored via AST + fallbacks; publish subset into COB comments on snapshot.  
- **Nix runner** + **container runner** with per‑repo selection.  
- **Artifacts to S3**, **manifests to IPFS**; link in Task COB.  
- **Realtime sessions (WebRTC)**: Y‑CRDT buffers; checkpoint → session branch patch.  
- **Headless mode**: act as relay (signaling/TURN optional), IPFS pinning, runner pool.

**Exit checks:**  
- Two NATed peers collaborate; tasks appear/resolve; builds reproduce across nodes; artifacts fetched (p95 < 3s from S3 for 100MB).

### M2 — Hardening & DevEx
- Improved anchor relocation; symbol index; semantic index for search.  
- Provenance (hashes, inputs) recorded in manifests; signature plumbing ready (keys in keychain).  
- Basic policy UI; deny merges without successful runner status.

### M3 — **Agents (propose‑only)**
- Agent runtime: Local/Remote/Peer backends; capability tokens; OS keychain.  
- Test‑gated patch proposal; self‑review; rollback thresholds.  
- Scheduling with leases in CRDT task queue.

### M4 — Optional Runners & Provenance
- Bazel runner; MicroVM (Firecracker); WASM for linters.  
- in‑toto‑like provenance + signatures; policy: require verified provenance for merge.

## Workstreams

**Radicle Integration**  
- CLI shim first; abstract behind `RadBackend`.  
- COB schemas: `task@v1` and `artifact@v1` (artifact COB stores *manifests*, not payloads).

**CRDT & Anchors**  
- Automerge for comments; Y‑CRDT for buffers.  
- Anchors: symbol path + AST digest; diff‑based fallback; detached state.

**Realtime**  
- WebRTC data channels; simple signaling (HTTPS on the headless node).  
- Periodic checkpoints to Git; announce live session via a small COB pointer.

**Runners & Artifacts**  
- Nix/container runners; S3 uploader with multipart; IPFS add/pin for manifests.  
- Background prefetch/cache on artifact open.

**Policy & Security**  
- Ed25519 identities; sign actions.  
- Capability tokens per repo; no secrets in repo.  
- Sandboxing defaults to container; escalate to MicroVM if configured.

## Testing

**Property tests** for CRDT merges & anchor relocation.  
**Integration** across 3 nodes (offline/online, NAT + relay).  
**Determinism**: same inputs → same outputs (hash equality).  
**Performance**: artifact upload/download latency; checkpoint cost; Radicle sync times.

## Risks & Mitigations
- **Radicle API surface changes** → stay on CLI adapter behind trait; pin versions.  
- **Realtime NAT pain** → use WebRTC + TURN; degrade to relay early.  
- **Anchor misses on heavy refactors** → visible “detached” state; quick re‑anchor UX.  
- **S3 creds on headless** → age‑encrypted file or external secrets manager.

```

---

### Notes & references

- Radicle treats **Collaborative Objects (COBs)** as the social primitive (issues/patches/discussions) implemented as Git objects and replicated by the Radicle node; COBs are CRDT‑like and designed for durability, not per‑keystroke traffic.  [oai_citation:5‡radicle.xyz](https://radicle.xyz/?utm_source=chatgpt.com) [oai_citation:6‡LWN.net](https://lwn.net/Articles/966869/?utm_source=chatgpt.com)  
- Radicle provides a **protocol and gossip layer** purpose‑built for Git/COBs; we use it for durable state and rely on **WebRTC** for ephemeral realtime traffic to avoid turning Y‑CRDT deltas into Git churn.  [oai_citation:7‡radicle.xyz](https://radicle.xyz/guides/protocol?utm_source=chatgpt.com)  
- **Radicle CI broker** and adapters already exist; our MVP leans on them for server‑optional CI while we standardize runners and artifact handling.  [oai_citation:8‡radicle-ci.liw.fi](https://radicle-ci.liw.fi/radicle-ci-broker/userguide.html?utm_source=chatgpt.com) [oai_citation:9‡Docs.rs](https://docs.rs/radicle-ci-broker?utm_source=chatgpt.com) [oai_citation:10‡radicle.xyz](https://radicle.xyz/2025/07/23/using-radicle-ci-for-development?utm_source=chatgpt.com)
