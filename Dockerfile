# syntax=docker/dockerfile:1
# Matching Debian versions keep the release's native runtime compatible.
ARG BUILDER_IMAGE=hexpm/elixir:1.20.4-erlang-29.1.1-debian-trixie-20260918-slim
ARG RUNNER_IMAGE=debian:trixie-20260918-slim

FROM ${BUILDER_IMAGE} AS build
RUN apt-get update && apt-get install -y --no-install-recommends build-essential git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ENV MIX_ENV=prod
RUN mix local.hex --force && mix local.rebar --force
COPY mix.exs mix.lock ./
COPY config/config.exs config/prod.exs config/
RUN mix deps.get --only prod && mix deps.compile
RUN mix assets.setup
COPY lib lib
COPY priv priv
COPY assets assets
RUN mix compile && mix assets.deploy
COPY config/runtime.exs config/runtime.exs
RUN mix release

FROM ${RUNNER_IMAGE} AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
      libstdc++6 openssl libncurses6 ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 scout \
    && useradd --uid 10001 --gid scout --home-dir /app --no-create-home scout
WORKDIR /app
ENV LANG=C.UTF-8 \
    MIX_ENV=prod \
    PHX_SERVER=true \
    PORT=4000 \
    SCOUT_DATA_DIR=/app/data \
    ERL_CRASH_DUMP=/app/data/erl_crash.dump
COPY --from=build --chown=scout:scout /app/_build/prod/rel/job_scout ./
RUN mkdir -p /app/data && chown scout:scout /app/data && chmod 700 /app/data
USER scout
EXPOSE 4000
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl --fail --silent --output /dev/null http://localhost:4000/ || exit 1
CMD ["/app/bin/job_scout", "start"]
