# Part Approval App API Handoff

This document is for another AI agent that needs to work on this Flutter app without rereading the whole codebase. It describes every backend API currently represented in the app, the purpose of each endpoint, how the client sends requests, and what response shapes the app can tolerate.

## Scope

- App type: Flutter desktop/web client
- Primary API client file: [lib/part_request_api.dart](/Users/devedocument/Documents/PM_Part Approval/lib/part_request_api.dart)
- Main UI integration file: [lib/main.dart](/Users/devedocument/Documents/PM_Part Approval/lib/main.dart)
- Production default base URL: `https://sit.printer-manager.com/`
- API style: JSON over HTTP with bearer-token auth after login

## Runtime Configuration

The app uses compile-time Dart environment variables:

- `API_BASE_URL`
  - Purpose: overrides the backend base URL
  - Default: `https://sit.printer-manager.com/`
- `DEMO_MODE`
  - Purpose: bypasses the live backend and uses in-memory sample data
  - Default: `false`

Example run:

```bash
 flutter run --dart-define=API_BASE_URL=https://sit.printer-manager.com/
flutter run --dart-define=DEMO_MODE=true
```

## HTTP Client Rules

All requests are sent through `PartRequestApi`.

Default headers:

```http
Accept: application/json
Content-Type: application/json; charset=utf-8
```

Authenticated requests also include:

```http
Authorization: Bearer <token>
```

Notes:

- Login is the only request sent without the auth header.
- The app stores the token only in memory inside `PartRequestApi`; there is no persisted session storage in the current implementation.
- Any non-2xx response throws `ApiException`.
- Error messages are extracted in this order:
  - `message`
  - `error`
  - `errors`
  - fallback: `Request failed (<statusCode>).`

## Flexible Response Parsing

The client is intentionally tolerant of backend response wrappers.

### Token extraction after login

The app accepts the token from any of these locations:

- `token`
- `access_token`
- `data.token`
- `data.access_token`

### List extraction

For list endpoints, the app accepts the list from:

- `data`
- `results`
- `items`
- top-level response body if the body itself is a list
- `data.data` as a nested fallback

### Single-item extraction

For item/detail endpoints, the app accepts the object from:

- `data`
- `item`
- top-level response body if the body itself is already an object

This means a replacement backend should preserve the fields, but it does not have to match one exact wrapper format.

## Endpoints

### 1. Login

- Client method: `PartRequestApi.login`
- HTTP method: `POST`
- Path: `/api/mobile/login`
- Auth required: no
- Purpose: authenticate the user and obtain a bearer token
- Used in UI: yes, during sign-in

Request body:

```json
{
  "email": "tech@printer-manager.com",
  "password": "secret"
}
```

Successful response examples accepted by the app:

```json
{
  "token": "jwt-or-api-token"
}
```

```json
{
  "data": {
    "access_token": "jwt-or-api-token"
  }
}
```

Usage notes:

- If login succeeds but no token is found in any accepted location, the app throws an error.
- On web builds, browser login may fail because the backend can reject `POST /api/mobile/login` via CSRF/origin policy. The app explicitly warns that desktop builds are safer for live login.

### 2. Current User Profile

- Client method: `PartRequestApi.getProfile`
- HTTP method: `GET`
- Path: `/api/mobile/profile`
- Auth required: yes
- Purpose: fetch the logged-in approver profile shown in the dashboard shell
- Used in UI: yes, immediately after login

Expected fields consumed by the app:

```json
{
  "data": {
    "id": 1,
    "name": "Demo Approver",
    "email": "demo.approver@printer-manager.com",
    "profile_photo_url": null
  }
}
```

Usage notes:

- Only `name`, `email`, and `profile_photo_url` are used by the current UI.
- If profile fetch fails, the app still continues using the login email as a fallback identity.

### 3. List Part Requests

- Client method: `PartRequestApi.listPartRequests`
- HTTP method: `GET`
- Path: `/api/mobile/part-request`
- Auth required: yes
- Purpose: load the approval dashboard request list
- Used in UI: yes, on initial dashboard load and every 20 seconds for auto-refresh

Minimal item shape expected by the current UI:

```json
{
  "id": 5001,
  "part_name": "Cyan Drum Kit",
  "brand_id": 1,
  "brand": { "id": 1, "name": "Canon" },
  "brand_model_id": 11,
  "brand_model": { "id": 11, "name": "iR ADV DX C3926" },
  "machine_id": 101,
  "machine": { "id": 101, "name": "HQ Printer A" },
  "part_category_id": 201,
  "part_category": { "id": 201, "name": "Drum Unit" },
  "user": { "id": 7, "name": "Aisyah" },
  "cost": 780.0,
  "created_at": "2026-04-02",
  "description": "Drum count is high and print quality shows repeated marks.",
  "remark": "Need urgent approval before next PM cycle.",
  "status": 1,
  "status_id": 1
}
```

Usage notes:

- The list is sorted client-side by `created_at`, newest first.
- The UI can search and filter locally after loading this list.
- The app tracks new request IDs between refreshes to show a “new requests found” snackbar.

### 4. Show Part Request Detail

- Client method: `PartRequestApi.showPartRequest`
- HTTP method: `GET`
- Path: `/api/mobile/part-request/{id}`
- Auth required: yes
- Purpose: fetch a single request with fuller data before status updates
- Used in UI: yes, but only when the list item lacks the IDs needed for update payload construction

Example:

```http
GET /api/mobile/part-request/5001
```

Usage notes:

- The current UI first tries to update from list data.
- If any of these IDs are missing, it fetches detail before sending the update:
  - `brand_id`
  - `brand_model_id`
  - `machine_id`
  - `part_category_id`

### 5. Create Part Request

- Client method: `PartRequestApi.createPartRequest`
- HTTP method: `POST`
- Path: `/api/mobile/part-request`
- Auth required: yes
- Purpose: create a new part request
- Used in UI: not currently wired into the production Flutter screens, but fully implemented in the API client

Request body:

```json
{
  "part_name": "Upper Fuser Roller",
  "description": "Temperature inconsistency during long print runs.",
  "remark": "Urgent replacement requested.",
  "brand_id": 2,
  "brand_model_id": 21,
  "machine_id": 102,
  "part_category_id": 202,
  "status": 1,
  "status_id": 1
}
```

Usage notes:

- The client does not enforce a schema for creation; it forwards the provided map as-is.
- Another agent adding a create screen should reuse the same key names used elsewhere in the app:
  - `part_name`
  - `description`
  - `remark`
  - `brand_id`
  - `brand_model_id`
  - `machine_id`
  - `part_category_id`
  - optionally `status` and `status_id`

### 6. Update Part Request

- Client method: `PartRequestApi.updatePartRequest`
- HTTP method: `PUT`
- Path: `/api/mobile/part-request/{id}`
- Auth required: yes
- Purpose: update an existing part request, currently used for approval status changes
- Used in UI: yes

Current update payload built by the UI:

```json
{
  "part_name": "Cyan Drum Kit",
  "description": "Drum count is high and print quality shows repeated marks.",
  "remark": "Need urgent approval before next PM cycle.",
  "status": 2,
  "status_id": 2,
  "brand_id": 1,
  "brand_model_id": 11,
  "machine_id": 101,
  "part_category_id": 201
}
```

Usage notes:

- The UI does not send a partial status-only patch. It sends a full update payload containing:
  - `part_name`
  - `description`
  - `remark`
  - `status`
  - `status_id`
  - related foreign keys when available
- Status changes always require user confirmation in the UI before the request is sent.
- After a successful update, the returned item is reparsed and merged back into the local list.

### 7. Search Part Requests

- Client method: `PartRequestApi.searchPartRequests`
- HTTP method: `POST`
- Path: `/api/mobile/search/part-requests`
- Auth required: yes
- Purpose: server-side search/filter for part requests
- Used in UI: not currently used by the live Flutter screens

Request body:

```json
{
  "status_id": [1, 2],
  "machine_id": 101,
  "brand_id": 1,
  "created_at": {
    "from": "2026-04-01",
    "to": "2026-04-16"
  }
}
```

Usage notes:

- The client forwards any filter map as-is.
- The current UI does all filtering locally after `listPartRequests`, so this method is ready for future use but not yet integrated.

## Data Model Consumed By The UI

The UI converts backend JSON into the `PartRequest` model. These fields are the most important.

### Core request fields

- `id`
- `part_name`
- `description`
- `remark`
- `cost`
- `created_at`

### Relationship fields

The parser supports both flat IDs and nested objects.

- Brand
  - `brand_id`
  - `brand.name`
  - fallback: `brand_name`
- Model
  - `brand_model_id`
  - `brand_model.name`
  - fallback: `brand_model_name`
- Machine
  - `machine_id`
  - `machine.name`
  - fallback: `machine_name`
- Category
  - `part_category_id`
  - `part_category.name`
  - fallback: `part_category_name`
- Requester
  - `user.name`
  - fallback: `created_by.name`
  - fallback: `user_name`

### Status field parsing

The parser accepts status from:

- `status`
- `status_id`
- `approval_status`

It can interpret:

- integer IDs
- numeric strings
- object form such as `{ "id": 2, "name": "Approved" }`
- label strings such as `"Approved"`

Compatibility note:

- The current parser also treats the legacy label `"New"` as `Requested` so the UI can tolerate backend responses during rollout.

## Status Mapping Used By This App

The app uses this exact status enum:

| API value | Label |
| --- | --- |
| `1` | `Requested` |
| `2` | `Approved` |
| `3` | `Pending` |
| `4` | `Collected` |
| `5` | `Returned` |
| `6` | `Used` |
| `7` | `Disposed` |

Important behavior:

- `Disposed` is treated as the only closed status in the current UI.
- Status chips and update actions are driven entirely from this mapping.

## Actual App Flow

The current production flow in [lib/main.dart](/Users/devedocument/Documents/PM_Part Approval/lib/main.dart) is:

1. User calls `login(email, password)`.
2. App stores the returned token in memory.
3. App calls `getProfile()`.
4. App calls `listPartRequests()`.
5. App auto-refreshes `listPartRequests()` every 20 seconds.
6. If an approver changes status:
   - app confirms the action
   - app may call `showPartRequest(id)` if IDs are missing
   - app sends `updatePartRequest(id, payload)`

## Example Dart Usage

```dart
final api = PartRequestApi();

await api.login(
  email: 'tech@printer-manager.com',
  password: 'secret',
);

final profile = await api.getProfile();
final requests = await api.listPartRequests();

final detail = await api.showPartRequest(5001);

  final updated = await api.updatePartRequest(5001, {
  'part_name': detail['part_name'],
  'description': detail['description'],
  'remark': detail['remark'],
  'status': 2,
  'status_id': 2,
  'brand_id': detail['brand_id'],
  'brand_model_id': detail['brand_model_id'],
  'machine_id': detail['machine_id'],
  'part_category_id': detail['part_category_id'],
});
```

## Guidance For Another Agent

- If you are extending the current app, treat `lib/part_request_api.dart` as the source of truth for endpoint paths and tolerant response parsing.
- If you are adding create or server-side search UI, the client methods already exist and can be wired directly.
- If the backend response format changes, preserve the field names consumed by `PartRequest.fromJson` and `UserProfile.fromJson` unless you also update the parsers.
- If you need persistent login, that is not implemented yet; you would need to add secure/local storage around the in-memory token.
- If you target Flutter web against the live backend, validate CSRF/CORS behavior early because login is the most likely browser failure point.
