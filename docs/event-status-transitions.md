# Event status transitions

Stored statuses are `draft`, `under_review`, `published`, `rejected`, `cancelled`, and `cancelled_by_organizer`. `Pending` and `Failed` from the requirements stay on the client and are not columns. `cancelled` is the creation-time value from the original status list; abandoning the wizard does not call the API. Organizer cancellation of a published event is `cancelled_by_organizer`.

| From | To | Who | Where |
| --- | --- | --- | --- |
| none | `draft` | owner or manager | `POST /organizations/{id}/events` (US-5.1) |
| `draft` or `rejected` | `under_review` | owner or manager, event complete | `POST /organizations/{id}/events/{event_id}/submit` (US-5.3) |
| `under_review` | `published` or `rejected` | moderator | `Events::Transition` only. HTTP stays in US-6.2 |
| `published` | `cancelled_by_organizer` | owner or manager | `Events::Transition` only. HTTP stays in US-5.5 |

`PUT /organizations/{id}/events/{event_id}` edits a `draft` or `rejected` event and does not change its status. `under_review`, `published`, `cancelled`, and `cancelled_by_organizer` return 403. A published event is edited through a revision in US-5.4.

An incomplete submit stays in its current status and writes no history row. Every successful transition writes one `event_status_histories` row.
