# Job Scout

A local Elixir/Phoenix job-search assistant powered by Ollama. Phase 1 will cover multi-source job discovery, fit ranking, evidence-backed resume tailoring, and cover-letter creation/optimization. Users supply their own countries and preferences. The human submits applications.

## Implemented now

- Phoenix LiveView onboarding with sample resume text, progress, cancellation, and editable profile/preferences.
- Local Ollama structured profile extraction (default `llama3.1:latest`).
- Ecto validation and verbatim evidence checks. These checks do **not** prove that every extracted summary or skill is grounded; user review remains necessary.
- Local candidate snapshots and run metadata with prompt version, elapsed time and token counts. Resume bodies are excluded from trace records; reviewed profiles contain personal data and remain local.
- Durable, serialized quota reservations tested for concurrent requests, restart persistence and corrupted records. Not yet connected to a search adapter.
- Offline tests; no job-source credits required.

## Run

Requirements: Elixir 1.17+ with Erlang/OTP, and a running Ollama installation.

```sh
cd ~/Desktop/job-scout
mix setup
ollama list
mix phx.server
```

Open <http://localhost:4000>. Paste a resume or use the synthetic sample. Model initialization may take a few minutes.

Optional configuration:

```sh
cp .env.example .env
# Edit .env locally; it is ignored by Git.
set -a
source .env
set +a
mix phx.server
```

No Python service, PostgreSQL, cloud LLM, or API key is needed for this milestone. The app binds to loopback in development. It is a personal local application, not an authenticated hosted service.

## Checks

```sh
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

## Local data

`data/local/` contains private candidate snapshots and run records and is excluded from Git. The UI saves candidates but does not yet list/reload them. Tests use isolated temporary directories or `data/test/`. Treat the quota store as single-node: do not run multiple app instances against the same data directory.

## Next milestones

See [the implementation plan](docs/phase-1.md). The current UI deliberately does not claim that search or document tailoring is implemented yet.

Reference: <https://github.com/jamwithai/observable-job-agent/tree/part1.0>.
