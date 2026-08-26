# Product Pulse Handoff

Use this asset only when preparing or refreshing a handoff at a hold, rollback, gate advance, or final completion. Refresh one compact block in the launch ticket. Keep raw observation rows append-only; the handoff summarizes and points to them rather than copying every sample.

```markdown
## PRODUCT PULSE HANDOFF

- Stable launch identity: <immutable release/artifact/deploy ID or canonical launch ID>
- Evidence window: <start UTC> to <stop UTC>
- Release / launch: <release identity and current gate>
- Source launch ticket: <URL or path; mark temporary when it will be retired>
- Durable evidence record: <approved retained URL/path, or pending until the record is created>
- Decision history and current outcome: <advance | hold | rollback | complete, with timestamps>
- Sampling plans and observation record: <ticket section containing every gate/plan ID and all append-only sample rows>

| Source ID | Provenance | Dimensions | Evidence window | Source evidence pointer | Durable evidence pointer | Limitations |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| <stable ID> | <provider telemetry/query | issue/support export | operator/manual | unavailable> | <usage, quality, errors, performance, customer signals> | <UTC range> | <dashboard/query/export/ticket row> | <retained record section or approved access-controlled record> | <coverage or access limits> |

- Unresolved signals and requirements: <every yellow/red observation, CONFUSION, UNVERIFIED, and MISSING REQUIREMENT entry, including owners and stop boundaries, or none>
- Coverage gaps and owners: <missing or partial source, owner, stop boundary, and next step, or none>
```

Keep the stable launch identity, gate / plan IDs, and Source IDs unchanged when the same launch evidence is refreshed or copied. Do not label the whole handoff measured: provenance stays attached to each source so a later pulse can distinguish telemetry, manual observations, and unavailable evidence. Before retiring a temporary launch ticket, create exactly one canonical durable evidence record: run `kramme:product:pulse` in file mode while the ticket remains available and verify its report contains this handoff, every gate's complete sampling plan, and every append-only observation row, or copy the same material to an approved durable launch tracker and point the pulse input at it. Later pulse reports reference that canonical record instead of duplicating its complete history.

Before copying evidence, verify the durable destination's audience is no broader than the source and that its retention is appropriate. Never persist secrets, credentials, credential-bearing URLs, or unredacted personal/customer data in repository reports. Minimize internal identifiers and raw payloads; when an unsanitized audit copy is required, keep it in a source-equivalent access-controlled system and retain only a sanitized summary plus opaque pointer in the pulse report. If no safe durable destination exists, emit `MISSING REQUIREMENT` and retain the temporary ticket.

Preserve cadence and its source, original start and stop bounds, decision queries, threshold sources, denominators, sample-sufficiency rules and states, early stop conditions, watcher or recurrence details, decision history, unresolved markers, and limitations. Running `kramme:product:pulse` is not by itself proof that the evidence is durable. Before cleanup, replace every temporary ticket-row pointer with a durable record pointer, verify every retained evidence pointer will remain resolvable after retirement, and confirm the canonical record will remain accessible. Do not retire a temporary `LAUNCH.md` while it contains the only copy of unconsumed handoff evidence.

At final completion, verify every gate / plan ID and referenced observation row is present in exactly one approved canonical durable record, every open marker retains its owner and stop boundary, and every durable evidence pointer will remain resolvable after the temporary launch ticket is retired.
