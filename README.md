# Musto

Musto is a Rails 8.1 prototype for a Gusto-style HR, payroll, benefits, and compliance operations platform with a deep Vitable Connect integration.

It models the local system of record for organizations, employers, employees, benefit plans, enrollments, payroll runs, payroll deductions, Vitable integration connections, webhook events, sync runs, and API request logs. The app is intentionally credential-aware: it works without a Vitable API key, records missing-credential states, and is ready to call the Vitable SDK when `VITABLE_CONNECT_API_KEY` is configured.

## Stack

- Ruby 4.0.5 target
- Rails 8.1.3
- SQLite for local proofing
- Tailwind CSS via `tailwindcss-rails`
- Vitable SDK: `vitable-connect ~> 0.5.0`
- Solid Cache, Solid Queue, and Solid Cable

## Vitable Integration Notes

The Vitable docs used for this scaffold:

- `https://developer.vitablehealth.com/`
- `https://developer.vitablehealth.com/api/ruby/`
- `https://developer.vitablehealth.com/webhooks/introduction/`

The SDK is initialized through `Vitable::ClientGateway`, using `IntegrationConnection#api_key_reference` to read credentials from the environment. By default this is:

```sh
VITABLE_CONNECT_API_KEY=...
VITABLE_CONNECT_ENVIRONMENT=demo
VITABLE_CONNECT_BASE_URL=https://api.demo.vitablehealth.com
VITABLE_WEBHOOK_SECRET=...
```

Webhook payloads are stored idempotently by `event_id`. Vitable webhook events include identifiers only, so `Vitable::ProcessWebhookCommand` records the event and, when credentials exist, calls `Vitable::FetchResourceCommand` to retrieve the fresh resource state.

The Vitable employer provisioning workspace builds the `POST /v1/employers` payload and, once a remote employer ID exists, switches to the settings update path for pay frequency. It uses DTO-backed packet review, repository-generated holdbacks, and `needs_credentials` sync runs so the create path can be proofed before an API key exists.

The Vitable census sync workspace builds a local review manifest for `POST /v1/employers/:id/census-sync`, separates ready employee rows from holdbacks, and records submit attempts as `SyncRun` rows. Without `VITABLE_CONNECT_API_KEY`, submits are accepted by the app as `needs_credentials` runs so the full workflow can be proofed before live credentials exist.

The benefit plan administration workspace reconciles local plans against Vitable's read-only `GET /v1/plans` catalog. It records mapped, unmatched, and ambiguous plans so downstream member sync uses real Vitable plan IDs instead of generated placeholders.

The embedded enrollment session workspace prepares employee-bound access-token requests for Vitable's embedded flows. It uses `bound_entity: { type: :employee, id: "empl_..." }`, records every issue attempt as a `SyncRun`, and filters token values before any API telemetry is persisted.

The care groups workspace covers Vitable Embedded Care group creation plus asynchronous group member sync. Member manifests require remote Vitable plan IDs; missing plan mappings are recorded as holdbacks so demo submissions do not fabricate partner identifiers.

## CQRS Layout

- Commands: `app/commands`
- Queries: `app/queries`
- DTOs: `app/dtos`
- Vitable gateway: `app/services/vitable/client_gateway.rb`
- JSON serializers: `app/serializers`

Controllers stay thin and delegate writes to commands:

- `POST /api/v1/employers`
- `POST /api/v1/webhooks/vitable`

Read-side UI:

- `GET /`
- `GET /employers`
- `GET /employers/:id`
- `GET /integrations/vitable/employer-provisioning`
- `GET /integrations/vitable/census`
- `GET /integrations/vitable/embedded-sessions`
- `GET /integrations/vitable/care-groups`

## Local Setup

```sh
bundle install
bin/rails db:prepare
bin/rails db:seed
bin/dev
```

The seed data creates a sample organization, Vitable connection placeholder, employer, roster, plans, enrollments, payroll deductions, and a sample webhook event.

## Webhook Smoke Test

```sh
curl -X POST http://localhost:3000/api/v1/webhooks/vitable \
  -H "Content-Type: application/json" \
  -d '{
    "event_id": "wevt_local_smoke",
    "organization_id": "org_demo_vitable",
    "event_name": "enrollment.accepted",
    "resource_type": "enrollment",
    "resource_id": "enrl_local_smoke",
    "created_at": "2026-01-23T14:30:00+00:00"
  }'
```

Without `VITABLE_CONNECT_API_KEY`, the event is accepted and marked `needs_credentials`.

## Verification

```sh
bin/rails test
env RUBOCOP_CACHE_ROOT=/private/tmp/rubocop_cache bin/rubocop
```
