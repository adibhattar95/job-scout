# Phase 1 implementation plan

## Product scope

Personal local application usable for different candidate profiles. Ollama provides local inference. The user supplies target roles, countries, cities and work preferences. Search live jobs across JSearch/OpenWeb Ninja, Adzuna (when configured), and Remotive (for relevant remote searches). Offline samples are for tests/demo only. Select a job, tailor the resume, create or optimize a cover letter, review edits, and export. Never submit automatically.

## Milestones

1. Foundation and onboarding: Phoenix, Ollama adapter, validated profiles/preferences, run records, durable quota primitive. Initial implementation complete; PDF ingestion and candidate reload still pending.
2. Resume ingestion: PDF text extraction, source-addressable facts, user-confirmed additions, profile load/delete, clear scanned-PDF errors.
3. Discovery: job/source schemas, source adapters, 24-hour search cache, duplicate removal, source diagnostics, user-visible request plan. Verify provider documentation and billing units before enabling JSearch.
4. Ranking: batches, supported matched skills, eligibility unknowns, bounded query reformulation. Preserve constraints and prior results; stop if no new jobs.
5. Application drafts: resume edits plus new/existing cover-letter optimization. Each factual claim references resume or user-confirmed evidence; block unsupported facts and changes to dates, metrics or qualifications. Semantic verification requires review, not merely reference existence.
6. Review/export: before/after edits, editable drafts, one simple document template, preserve original input.
7. Baseline: multiple candidate backgrounds, target countries, sparse/non-English resumes; relevance, geographic fit, latency, quota consumption, factual fidelity. Fixed job fixtures plus separate live integration tests.

## JSearch budget policy

- User allowance: 200 requests/month. Proposed app limit: 180, with 20 reserved.
- Two external JSearch attempts/run by default, one page/query initially.
- Exact-query cache hits do not reserve requests.
- Reserve durably before dispatch; failed or timed-out attempts are counted conservatively.
- Retries and reformulations cannot bypass the budget.
- Confirm subscription reset date, pagination charge units, and failure accounting; do not assume calendar-month reset.
- Provider dashboard is authoritative if the key is used outside the app.
- No automatic monthly-reset integration is implemented yet.

## Observability

Local run records first. Record model, prompt version, token counts, source timings, queries, cache hits, and stop reason. Do not log full resume bodies or keys. Exporter remains optional; investigate Opik via OpenTelemetry/REST without assuming LangGraph graph rendering parity. CV upload to external telemetry must be opt-in.

## Explicit limitations of the initial slice

Text input only, 16,000-character limit, local JSON snapshots, no candidate history UI yet. Evidence substring checks catch invented quotations but not unsupported paraphrases. No external job requests, ranking, tailoring, PDF export, or baseline quality claim yet.
