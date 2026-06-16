# PR Plan Rejections

**Generated:** {{date}} **Source:** {{source file or description}} **Source type:** {{findings report / pre-clustered handoff}} **Planned at:** commit `{{short-sha}}`

This file is the persistent record for findings or plan candidates deliberately left out of the generated PR plans. Keep IDs stable during reconcile; append new records instead of renumbering old ones.

## Rejected or Excluded Findings

{{If there are rejected or excluded findings, include one row per item. Prefix each Description cell with NOTICED BUT NOT TOUCHING:. Never include secret values; cite only file/line and credential type.}}

| ID | Status | Source reference | Description | Reason | Evidence | Reconsider when |
| --- | --- | --- | --- | --- | --- | --- |
| `REJECTED-001` | ACTIVE | {{source path / section / line}} | NOTICED BUT NOT TOUCHING: {{short description}} | {{duplicate / already resolved / not actionable / out of scope / contradicted / deferred}} | {{evidence and relevant file:line, redacted if secret-related}} | {{condition that should reopen this item, or "Never unless source finding changes."}} |

## Reconcile Notes

{{During --reconcile, append status changes here without deleting the original record. Use statuses such as ACTIVE, RECONSIDER, RESOLVED_OUTSIDE_PLAN, SUPERSEDED, or CONFIRMED_NOT_TOUCHING.}}

| Date | ID | Change | Reason |
| --- | --- | --- | --- |
| {{date}} | `REJECTED-001` | {{status change or "Created"}} | {{why}} |

## Empty Record

{{If no findings were rejected or excluded, replace the tables above with: "No findings were rejected or excluded for this generation."}}
