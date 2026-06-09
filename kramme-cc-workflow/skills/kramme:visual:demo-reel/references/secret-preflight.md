# Secret and Sensitive-Data Preflight

Recordings must not contain credentials, tokens, private data, or destructive actions. Assume anything visible in a screenshot, URL bar, terminal command, terminal output, network panel, or config screen is leaked.

## Hard Stops

Stop and ask before recording when the planned evidence would show:

- credentials, access tokens, API keys, auth headers, cookies, or signed URLs,
- customer data, private messages, production admin surfaces, billing details, or personal data,
- destructive flows such as delete, purchase, send, publish, deploy, or irreversible migration,
- hidden setup commands that must be visible to make the demo work,
- authenticated/private surfaces the user has not explicitly approved for recording.

## Patterns to Scan

Before recording and before reporting artifacts, scan visible text and transcripts for:

- `sk-`, `ghp_`, `ghs_`, `xoxb-`, `xoxp-`,
- `Bearer `, `Authorization:`, `Cookie:`, `Set-Cookie:`,
- `?token=`, `api_key=`, `access_token=`, `client_secret=`,
- `.env` contents,
- long hex/base64-like values near credential-sounding labels.

## Safe Capture Rules

- Set secrets before recording, outside the recorded region. Show the authenticated result, not the auth step.
- Prefer environment variables over CLI flags when a command needs credentials.
- Do not type fake placeholders in the recording. A fake value can both break the demo and leak the shape of the real secret.
- Do not plan to blur, crop, or edit secrets after capture. If a secret appears, discard and recapture.
- For sensitive authenticated UI, use a demo account or sanitized local seed data.
- For destructive workflows, use dry-run mode, a preview screen, or a local disposable fixture.
