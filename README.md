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


## Docker (local use)

The multi-stage image compiles assets and an Elixir release, then runs it as a non-root user. No host Elixir installation is required. Docker Desktop and a running host Ollama instance with the configured model are required.

First-time configuration:

```sh
cp .env.docker.example .env.docker
# Paste the output of this command into SECRET_KEY_BASE in .env.docker:
openssl rand -hex 64
```

Start the app:

```sh
docker compose --env-file .env.docker up --build -d
docker compose --env-file .env.docker ps
docker compose --env-file .env.docker logs -f app
```

Open <http://localhost:4001>. The development server can continue using port 4000. Use `SCOUT_PORT` in `.env.docker` to choose a different browser port. Both the published port and Phoenix's external URL are configured together so LiveView can connect correctly.

The Compose file publishes only to `127.0.0.1`. This is a personal local app without authentication; the Docker setup does not make it a public hosting deployment.

Ollama stays on the Mac so it can use the host's acceleration and existing models. Inside a container, `localhost` refers to that container; `host.docker.internal` reaches the host through Docker Desktop. This setup does not install a second Ollama or download any models. If inference fails, verify host access with:

```sh
docker compose --env-file .env.docker exec app curl --fail http://host.docker.internal:11434/api/tags
```

On native Linux, `host-gateway` supplies the hostname, but a host Ollama server bound only to loopback may not be reachable. Configure an accessible Ollama endpoint through `OLLAMA_URL`; this setup does not change the host server's network binding.

Profiles, trace records and quota reservations persist in the `scout_data` named volume, separate from host `data/local/`. Keep one application container per volume. Secrets and all local data are excluded from the build context. Do not use `docker compose down --volumes` unless you intend to delete the container's saved data.

Stop while keeping data:

```sh
docker compose --env-file .env.docker down
```

Build and run the image without Compose:

```sh
docker build -t job-scout:local .
docker run --rm --init --name job-scout-app \
  --env-file .env.docker \
  -e PHX_HOST=localhost -e PHX_SCHEME=http -e PHX_PORT=4001 \
  --add-host=host.docker.internal:host-gateway \
  -p 127.0.0.1:4001:4000 \
  -v job-scout-standalone-data:/app/data job-scout:local
```

For the standalone command, keep the explicit published port and `PHX_PORT` in sync if changing ports. `SCOUT_PORT` is a Compose variable only. Never pass secrets as Docker build arguments.
