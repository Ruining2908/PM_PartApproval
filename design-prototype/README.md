# Part Approval Request Prototype

This is a standalone mobile-first UI prototype inspired by the API handoff in
`/Users/devedocument/Documents/PM_Part Approval/API_HANDOFF.md`.

## Included screens

- Login screen
- Part request dashboard
- Search and filter panel matching the provided search payload
- Request detail modal
- Create request modal

## Approval flow

Each part request card includes six floating status buttons on the right side:

1. New (`1`)
2. Pending (`2`)
3. Collected (`3`)
4. Returned (`4`)
5. Used (`5`)
6. Disposed (`6`)

These map naturally to `PUT /api/mobile/part-request/{id}` for status updates.

## API mapping used in the prototype

- `GET /api/mobile/part-request`
- `POST /api/mobile/part-request`
- `GET /api/mobile/part-request/{id}`
- `PUT /api/mobile/part-request/{id}`
- `POST /api/mobile/search/part-requests`

## Run locally

Open `/Users/devedocument/Documents/PM_Part Approval/design-prototype/index.html`
in a browser.

To turn this into a real app, replace the mock arrays in
`/Users/devedocument/Documents/PM_Part Approval/design-prototype/app.js` with
live fetch calls and bearer-token auth using the login flow from the handoff.
