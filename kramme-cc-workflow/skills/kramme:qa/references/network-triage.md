# Network Triage

Apply this ladder to every failed or anomalous request:

| Signal | Interpretation | Action |
| --- | --- | --- |
| `4xx` | Client sent wrong data (shape, auth, validation) | Capture the request payload + route; Major unless expected, such as 401 on a logged-out probe |
| `5xx` | Server error | Capture the response body after redacting tokens; Blocker |
| CORS failure | Origin or headers mismatch | Capture origin + `Access-Control-*` response headers; Major |
| Timeout | Response exceeded the time budget, default > 3s | Capture URL + elapsed; Major unless route is known-slow |
| Missing | A request that was expected never fired | Capture route context; Major, often a regression signal |

