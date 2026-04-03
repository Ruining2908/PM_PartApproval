# WOD V3 API And Integration Handoff

This file is a handoff for another agent building a separate Flutter app from the same backend contract.

## Project Overview

- App name: `WOD App`
- Repository: `https://github.com/E-DSSB/wod_v3.git`
- Production API base URL: `https://printer-manager.com`
- API style: JSON over HTTP
- Auth style: Bearer token in `Authorization` header
- HTTP client in current app: `dio`

## Global API Configuration

- Base URL: `https://printer-manager.com`
- Default headers:
  - `Accept: application/json`
  - `Content-Type: application/json; charset=utf-8`
- Timeouts:
  - connect: 15s
  - receive: 15s
  - send: 15s
- Retry behavior in current app:
  - `GET`, `POST`, `PUT`, `DELETE` default to retry enabled
  - max retries: `3`

## Authentication

### Login

- Method: `POST`
- URL: `https://printer-manager.com/api/mobile/login`
- Request body:

```json
{
  "email": "user@example.com",
  "password": "secret"
}
```

- Expected success:
  - HTTP `200`
  - response contains `token`
- Current app behavior:
  - stores `data["token"]`
  - then fetches profile

### Auth Header

After login, all authenticated requests send:

```http
Authorization: Bearer <token>
```

### Unauthorized Handling

- On HTTP `401`, current app clears the token and forces user back to login.

## Local Storage Contract Used By Current App

- token key: `auth_token`
- user key: `user_data`
- login flag key: `is_logged_in`

## API Endpoints

### 1. Login

- Method: `POST`
- Path: `/api/mobile/login`
- Full URL: `https://printer-manager.com/api/mobile/login`
- Purpose: authenticate user

### 2. Profile

- Method: `GET`
- Path: `/api/mobile/profile`
- Full URL: `https://printer-manager.com/api/mobile/profile`
- Purpose: fetch current logged-in user profile
- Current app expects:

```json
{
  "data": {
    "id": 123,
    "name": "User Name",
    "email": "user@example.com",
    "profile_photo_url": "..."
  }
}
```

### 3. Update Profile

- Method: `POST`
- Path: `/api/mobile/profile`
- Full URL: `https://printer-manager.com/api/mobile/profile`
- Purpose: update user profile
- Request body:

```json
{
  "name": "User Name",
  "email": "user@example.com"
}
```

### 4. Work Order Types

- Method: `GET`
- Path: `/api/mobile/work-order-type`
- Full URL: `https://printer-manager.com/api/mobile/work-order-type`
- Purpose: fetch work order type master data
- Current app expects a top-level JSON array, not wrapped in `data`

Example item shape:

```json
{
  "id": 1,
  "team_id": 1,
  "name": "PM",
  "description": "Preventive Maintenance",
  "default": true,
  "order": 1,
  "created_at": "2024-01-01 00:00:00",
  "updated_at": "2024-01-01 00:00:00",
  "deleted_at": null
}
```

### 5. Status List

- Method: `GET`
- Path: `/api/mobile/status`
- Full URL: `https://printer-manager.com/api/mobile/status`
- Purpose: fetch status master data
- Used to determine:
  - new
  - in progress
  - pending
  - closed
- Current app expects a top-level JSON array

Example item shape:

```json
{
  "id": 1,
  "team_id": 1,
  "name": "In Progress",
  "description": "Currently being serviced",
  "default": false,
  "closed": false,
  "order": 2,
  "created_at": "2024-01-01 00:00:00",
  "updated_at": "2024-01-01 00:00:00",
  "deleted_at": null
}
```

### 6. Search Work Orders

- Method: `POST`
- Path: `/api/mobile/search/work-orders`
- Full URL: `https://printer-manager.com/api/mobile/search/work-orders`
- Purpose: search/filter work orders by technician, date range, status, and optionally type/customer

Example request body used by current app:

```json
{
  "serviced_by_id": "60",
  "created_at": {
    "from": "2026-03-01",
    "to": "2026-04-03"
  },
  "status_id": ["1", "2", "3"],
  "work_order_type_id": "4",
  "customer_id": "12"
}
```

Notes:

- `serviced_by_id` is sent as a string.
- `status_id` is sent as an array of string IDs.
- `work_order_type_id` and `customer_id` are optional.
- Current app expects:

```json
{
  "data": [
    {
      "id": 1001,
      "created_at": "2026-04-02 08:00:00",
      "attend_at": "2026-04-02 09:00:00",
      "customer": {},
      "machine": {},
      "work_order_type": {},
      "status": {},
      "time_in": "2026-04-02 09:05:00",
      "time_out": null,
      "tags": []
    }
  ]
}
```

### 7. Work Order Detail

- Method: `GET`
- Path: `/api/mobile/work-orders/{workOrderId}`
- Example: `https://printer-manager.com/api/mobile/work-orders/123`
- Purpose: fetch full work order details and history

Current app expects:

```json
{
  "data": {
    "id": 123,
    "customer": {},
    "machine": {},
    "work_order_type": {},
    "status": {},
    "open_remarks": "",
    "close_remarks": "",
    "created_at": "2026-04-02 08:00:00",
    "attended_at": null,
    "time_in": "",
    "time_out": "",
    "history": [],
    "tags": []
  }
}
```

Important nested structures used by the app:

- `customer`
  - `id`
  - `name`
  - `phone`
  - `level`
- `machine`
  - `id`
  - `name`
  - `address`
- `status`
  - `id`
  - `name`
  - `closed`
- `work_order_type`
  - `id`
  - `name`
- `history[]`
  - `updated_at`
  - `open_remarks`
  - `close_remarks`
  - `serviced_by_id`
  - `attend_at_date_only`
  - `time_in_local`
  - `time_out_local`
  - `serviced_by`

### 8. Update Existing Work Order

- Method: `POST`
- Path: `/api/mobile/work-orders/{workOrderId}`
- Example: `https://printer-manager.com/api/mobile/work-orders/123`
- Purpose:
  - start work order
  - update status
  - complete work order

#### Start Work Order Payload

```json
{
  "customer_id": 10,
  "machine_id": 20,
  "work_order_type_id": 3,
  "status_id": 2,
  "time_in": "2026-04-02 10:30:45"
}
```

#### Complete Work Order Payload

```json
{
  "customer_id": 10,
  "machine_id": 20,
  "work_order_type_id": 3,
  "status_id": 5,
  "close_remarks": "Completed successfully",
  "time_in": "2026-04-02 10:30:45",
  "time_out": "2026-04-02 12:15:00",
  "counter_bw": 1200,
  "counter_c": 450
}
```

#### Generic Status Update Payload

```json
{
  "customer_id": 10,
  "machine_id": 20,
  "work_order_type_id": 3,
  "status_id": 4,
  "time_in": "2026-04-02 10:30:45",
  "time_out": "2026-04-02 12:15:00"
}
```

### 9. Create Work Order

- Method: `POST`
- Path: `/api/mobile/work-orders`
- Full URL: `https://printer-manager.com/api/mobile/work-orders`
- Purpose:
  - create work order from QR scan
  - create follow-up work order

#### QR-based Create Payload

```json
{
  "customer_id": "10",
  "machine_id": "20",
  "work_order_type_id": "3",
  "status_id": "2",
  "open_remarks": "Created from QR scan for machine: Machine A (REF001)",
  "time_in": "2026-04-02 10:30:45"
}
```

Notes:

- In `MachineService.createWorkOrder`, these IDs are sent as strings.
- Current code treats HTTP `201` as success there.
- Another create flow also accepts HTTP `200` or `201`.

Expected success response may be either wrapped or unwrapped. Current code handles both styles for creation flows.

Unwrapped example:

```json
{
  "id": 999,
  "team_id": 1,
  "customer_id": "10",
  "machine_id": "20",
  "created_by_id": 1,
  "serviced_by_id": 1,
  "work_order_type_id": "3",
  "status_id": "2",
  "open_remarks": "Created from QR scan",
  "time_in": "2026-04-02 10:30:45",
  "time_out": null,
  "counter_bw": null,
  "counter_c": null,
  "parent_id": null,
  "attend_at": null,
  "updated_at": "2026-04-02 10:30:45",
  "created_at": "2026-04-02 10:30:45",
  "attend_at_date_only": "2026-04-02",
  "time_in_local": "10:30",
  "time_out_local": ""
}
```

Wrapped example also appears possible:

```json
{
  "data": {
    "id": 999
  }
}
```

### 10. Get Machine By QR UUID

- Method: `POST`
- Path: `/api/mobile/machine-for-qr`
- Full URL: `https://printer-manager.com/api/mobile/machine-for-qr`
- Purpose: resolve scanned QR UUID into machine details

Request:

```json
{
  "uuid": "b625d458-f754-4037-880c-79dc4bbf8cd0"
}
```

Expected response shape:

```json
{
  "status": "success",
  "machine": {
    "id": 20,
    "team_id": 1,
    "uuid": "b625d458-f754-4037-880c-79dc4bbf8cd0",
    "customer_id": 10,
    "name": "Machine A",
    "reference": "REF001",
    "serial_number": "SN123",
    "active": true
  }
}
```

## QR Code Contract

The current app expects QR content like:

```text
@https://printer-manager.com/redirect/b625d458-f754-4037-880c-79dc4bbf8cd0
```

Important:

- The app extracts the UUID from the QR content and then calls `/api/mobile/machine-for-qr`.
- The redirect URL pattern found in code is:
  - `https://printer-manager.com/redirect/{uuid}`

## External URLs, Deep Links, And Schemes Used

These are not backend APIs, but they are used by the current app.

### Sentry

- DSN:
  - `https://7c7a28866cb39d8a54f2fc2747771f12@o4510589392125952.ingest.us.sentry.io/4510589393764352`

### Avatar Fallback

- URL:
  - `https://ui-avatars.com/api/?name={INITIALS}&color=7F9CF5&background=EBF4FF&size=200&bold=true`

### Map Links

- Google Maps web:
  - `https://www.google.com/maps/search/?api=1&query={lat},{lng}`
  - `https://www.google.com/maps/search/?api=1&query={encodedAddress}`
- Android geo scheme:
  - `geo:{lat},{lng}?q={lat},{lng}`
  - `geo:0,0?q={encodedAddress}`
- Waze app scheme:
  - `waze://?ll={lat},{lng}&navigate=yes`
  - `waze://?q={encodedAddress}&navigate=yes`
- Waze web:
  - `https://waze.com/ul?ll={lat},{lng}&navigate=yes`
  - `https://waze.com/ul?q={encodedAddress}&navigate=yes`
- Apple Maps:
  - `https://maps.apple.com/?ll={lat},{lng}`
  - `https://maps.apple.com/?address={encodedAddress}`

### Phone / WhatsApp

- Phone:
  - `tel:{phoneNumber}`
- WhatsApp app scheme:
  - `whatsapp://send?phone={numberWithoutPlus}`
- WhatsApp web:
  - `https://wa.me/{numberWithoutPlus}`

## Known Validation / Error Behavior

- HTTP `401`
  - treated as expired session
  - token cleared
- HTTP `422`
  - treated as validation error
  - expected to include a `message`
- Other API failures
  - treated as connection/server errors

## Notes For The New Flutter App

- The current code does not use environment-based API switching. Base URL is hardcoded to production.
- Some endpoints return wrapped payloads with `data`, while others return top-level arrays or direct objects.
- Creation endpoints appear inconsistent and may return either:
  - direct object with `id`
  - wrapped object under `data`
- ID fields are sometimes sent as strings and sometimes as ints in the current app. A safer client should tolerate both.
- The work order search endpoint uses a POST body instead of query parameters.
- Status and work order type lists are important because business logic depends on names like:
  - PM
  - In Progress
  - Closed vs non-closed statuses

## Recommended Minimal Config Object For Another Agent

```json
{
  "baseUrl": "https://printer-manager.com",
  "defaultHeaders": {
    "Accept": "application/json",
    "Content-Type": "application/json; charset=utf-8"
  },
  "auth": {
    "type": "bearer",
    "loginPath": "/api/mobile/login",
    "tokenStorageKey": "auth_token"
  },
  "endpoints": {
    "profileGet": "/api/mobile/profile",
    "profileUpdate": "/api/mobile/profile",
    "workOrderTypes": "/api/mobile/work-order-type",
    "statuses": "/api/mobile/status",
    "searchWorkOrders": "/api/mobile/search/work-orders",
    "workOrderDetail": "/api/mobile/work-orders/{id}",
    "updateWorkOrder": "/api/mobile/work-orders/{id}",
    "createWorkOrder": "/api/mobile/work-orders",
    "machineForQr": "/api/mobile/machine-for-qr"
  }
}
```

## Source Files Used

- `lib/utils/app_constants.dart`
- `lib/services/api_service.dart`
- `lib/controllers/account_controller.dart`
- `lib/controllers/profile_controller.dart`
- `lib/controllers/work_order_controller.dart`
- `lib/controllers/work_order_detail_controller.dart`
- `lib/services/machine_service.dart`
- `lib/controllers/qr_scanner_controller.dart`
- `lib/models/work_order.dart`
- `lib/models/work_order_detail.dart`
- `lib/models/machine.dart`
- `lib/main.dart`
- `lib/pages/work_order_detail_page.dart`
