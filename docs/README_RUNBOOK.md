# OPS CORE V2 - Runbook (MVP)

## Scope (MVP vendable)
- Supabase Cloud = DB/Auth
- n8n local/cloud = orchestration
- Input: CSV impayés
- Output: drafts + approvals + export (NO-SEND)

## Core principles
- Ledger immutable: `events` append-only, PII redacted.
- Idempotence: `idempotency_key` + `locks`.
- Reliability: `jobs_queue` + retries + DLQ.
- Policy versioned: `policies` + `policy_version` frozen per `run`.
- Approvals: links signed HMAC, expiry 24h (token hash stored).

## Repo structure
- `core/migrations/` : core schema
- `packs/cash_collector/migrations/` : pack tables
- `core/policies/` : policy JSON versions
- `packs/cash_collector/templates/` : FR email templates
- `workflows/` : n8n exports/imports (JSON)

## Environments
- MVP: no VPS, no OVH, no SMTP prod.
- When vendable: add VPS single-tenant + HTTPS + SMTP + backups.

## Approvals (HMAC)
Links:
- Approve: /approve?run_id=...&approval_id=...&exp=...&sig=...
- Reject : /reject?...

Rules:
- exp < now => expired
- invalid sig => 401
- already decided => 409
- store `token_hash`, never raw token

## Cash Collector policy
- J+0 soft, J+7 firm, J+14 final (approval required)
- Dispute => stop auto + task + approval required
- Send window: Mon-Fri 09:00-18:00 (Europe/Paris)
- Safe mode: approval-first, no-auto-send

## Next build steps (when scheduled)
1) opsgen CLI skeleton (init/link/migrate/seed/import/smoke)
2) n8n workflows specs + exports committed
3) Supabase migrations applied + seed policy
4) Smoke test end-to-end with sample CSV
