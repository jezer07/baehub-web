# BaeHub API Documentation

Welcome to the BaeHub API! This RESTful API allows mobile clients to access all BaeHub features including expenses, tasks, events, and settlements.

## Base URL

```
http://localhost:3000/api/v1
```

For production, replace with your production URL.

## Authentication

The API uses JWT (JSON Web Token) authentication. After logging in or signing up, you'll receive:
- `token`: A short-lived JWT token (expires in 1 hour)
- `refresh_token`: A long-lived refresh token (expires in 30 days)

### Include Authentication Token

Include the JWT token in the `Authorization` header for all protected endpoints:

```
Authorization: Bearer YOUR_JWT_TOKEN
```

## Authentication Endpoints

### Sign Up

Create a new user account.

**Endpoint:** `POST /api/v1/auth/signup`

**Request Body:**
```json
{
  "user": {
    "name": "John Doe",
    "email": "john@example.com",
    "password": "password123",
    "password_confirmation": "password123",
    "timezone": "America/New_York",
    "preferred_color": "#FF5733"
  }
}
```

**Response:** `201 Created`
```json
{
  "user": {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "timezone": "America/New_York",
    "preferred_color": "#FF5733",
    "avatar_url": null,
    "prefers_dark_mode": false,
    "role": "partner",
    "solo_mode": false,
    "coupled": false,
    "couple_id": null
  },
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "refresh_token": "a1b2c3d4e5f6..."
}
```

### Log In

Authenticate with existing credentials.

**Endpoint:** `POST /api/v1/auth/login`

**Request Body:**
```json
{
  "email": "john@example.com",
  "password": "password123"
}
```

**Response:** `200 OK`
```json
{
  "user": { ... },
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "refresh_token": "a1b2c3d4e5f6..."
}
```

### Refresh Token

Get a new JWT token using your refresh token.

**Endpoint:** `POST /api/v1/auth/refresh`

**Request Body:**
```json
{
  "refresh_token": "a1b2c3d4e5f6..."
}
```

**Response:** `200 OK`
```json
{
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "refresh_token": "a1b2c3d4e5f6..."
}
```

### Log Out

Invalidate the current refresh token.

**Endpoint:** `DELETE /api/v1/auth/logout`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

**Response:** `200 OK`
```json
{
  "message": "Logged out successfully"
}
```

## User & Profile Endpoints

### Get User Profile

**Endpoint:** `GET /api/v1/users/profile`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

**Response:** `200 OK`
```json
{
  "user": {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "timezone": "America/New_York",
    "preferred_color": "#FF5733",
    "avatar_url": null,
    "prefers_dark_mode": false,
    "role": "partner",
    "solo_mode": false,
    "coupled": true,
    "couple_id": 1
  }
}
```

### Update User Profile

**Endpoint:** `PATCH /api/v1/users/profile`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

**Request Body:**
```json
{
  "user": {
    "name": "John Updated",
    "timezone": "America/Los_Angeles",
    "preferred_color": "#00FF00",
    "prefers_dark_mode": true
  }
}
```

### Update Password

**Endpoint:** `PATCH /api/v1/users/password`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

**Request Body:**
```json
{
  "current_password": "password123",
  "new_password": "newpassword456",
  "password_confirmation": "newpassword456"
}
```

### Get Couple Information

**Endpoint:** `GET /api/v1/users/couple`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

**Response:** `200 OK`
```json
{
  "couple": {
    "id": 1,
    "name": "John & Jane",
    "slug": "john-jane",
    "timezone": "America/New_York",
    "anniversary_on": "2023-06-15",
    "story": "We met in college...",
    "default_currency": "USD",
    "members": [
      { "id": 1, "name": "John Doe", "email": "john@example.com" },
      { "id": 2, "name": "Jane Doe", "email": "jane@example.com" }
    ]
  }
}
```

### Create a Couple

**Endpoint:** `POST /api/v1/users/couple/create`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

**Request Body:**
```json
{
  "couple": {
    "name": "John & Jane",
    "timezone": "America/New_York",
    "anniversary_on": "2023-06-15",
    "story": "We met in college...",
    "default_currency": "USD"
  }
}
```

### Join a Couple

**Endpoint:** `POST /api/v1/users/couple/join`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

**Request Body:**
```json
{
  "code": "ABC12345"
}
```

### Create Invitation

**Endpoint:** `POST /api/v1/users/couple/invite`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

**Request Body:**
```json
{
  "recipient_email": "partner@example.com",
  "message": "Join me on BaeHub!"
}
```

## Dashboard Endpoint

### Get Dashboard

Retrieve dashboard data including tasks, events, expenses, balance, and activity logs.

**Endpoint:** `GET /api/v1/dashboard`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

**Response:** `200 OK`
```json
{
  "tasks": [...],
  "events": [...],
  "expenses": [...],
  "balance": { ... },
  "activity_logs": [...],
  "invitations": [...]
}
```

## Expenses Endpoints

### List Expenses

**Endpoint:** `GET /api/v1/expenses`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

**Query Parameters:**
- `spender_id` (optional): Filter by spender ID
- `start_date` (optional): Filter by start date (YYYY-MM-DD)
- `end_date` (optional): Filter by end date (YYYY-MM-DD)

**Response:** `200 OK`
```json
{
  "expenses": [
    {
      "id": 1,
      "title": "Grocery Shopping",
      "amount_cents": 5000,
      "amount": 50.0,
      "currency": "USD",
      "incurred_on": "2024-01-15",
      "notes": "Weekly groceries",
      "split_strategy": "equal",
      "spender": {
        "id": 1,
        "name": "John Doe",
        "email": "john@example.com"
      },
      "shares": [
        {
          "user_id": 1,
          "user_name": "John Doe",
          "amount_cents": 2500,
          "amount": 25.0,
          "percentage": null
        }
      ]
    }
  ],
  "balance": { ... }
}
```

### Get Single Expense

**Endpoint:** `GET /api/v1/expenses/:id`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

### Create Expense

**Endpoint:** `POST /api/v1/expenses`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

**Request Body (Equal Split):**
```json
{
  "expense": {
    "title": "Grocery Shopping",
    "amount_cents": 5000,
    "incurred_on": "2024-01-15",
    "notes": "Weekly groceries",
    "split_strategy": "equal"
  }
}
```

**Request Body (Percentage Split):**
```json
{
  "expense": {
    "title": "Rent",
    "amount_cents": 200000,
    "incurred_on": "2024-01-01",
    "split_strategy": "percentage",
    "shares": {
      "1": 60,
      "2": 40
    }
  }
}
```

**Request Body (Custom Amounts):**
```json
{
  "expense": {
    "title": "Dinner",
    "amount_cents": 8000,
    "incurred_on": "2024-01-15",
    "split_strategy": "custom_amounts",
    "shares": {
      "1": 5000,
      "2": 3000
    }
  }
}
```

### Update Expense

**Endpoint:** `PATCH /api/v1/expenses/:id`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

**Request Body:** Same as create

### Delete Expense

**Endpoint:** `DELETE /api/v1/expenses/:id`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

## Tasks Endpoints

### List Tasks

**Endpoint:** `GET /api/v1/tasks`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

**Query Parameters:**
- `status` (optional): Filter by status (todo, in_progress, done, archived)
- `assignee_id` (optional): Filter by assignee ID
- `due_date` (optional): Filter by due date
- `sort_by` (optional): Sort by (due_date, priority, created_at)

**Response:** `200 OK`
```json
{
  "tasks": [
    {
      "id": 1,
      "title": "Buy groceries",
      "description": "Get milk, eggs, bread",
      "status": "todo",
      "priority": "normal",
      "due_at": "2024-01-20T10:00:00Z",
      "completed_at": null,
      "assignee": {
        "id": 1,
        "name": "John Doe",
        "email": "john@example.com"
      },
      "creator": {
        "id": 2,
        "name": "Jane Doe",
        "email": "jane@example.com"
      }
    }
  ]
}
```

### Get Single Task

**Endpoint:** `GET /api/v1/tasks/:id`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

### Create Task

**Endpoint:** `POST /api/v1/tasks`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

**Request Body:**
```json
{
  "task": {
    "title": "Buy groceries",
    "description": "Get milk, eggs, bread",
    "status": "todo",
    "priority": "normal",
    "due_at": "2024-01-20T10:00:00Z",
    "assignee_id": 1
  }
}
```

### Update Task

**Endpoint:** `PATCH /api/v1/tasks/:id`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

### Delete Task

**Endpoint:** `DELETE /api/v1/tasks/:id`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

### Toggle Task Completion

**Endpoint:** `POST /api/v1/tasks/:id/toggle_completion`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

## Events Endpoints

### List Events

**Endpoint:** `GET /api/v1/events`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

**Query Parameters:**
- `category` (optional): Filter by category
- `start_date` (optional): Filter by start date
- `end_date` (optional): Filter by end date
- `sort_by` (optional): Sort by (starts_at, created_at)

### Get Single Event

**Endpoint:** `GET /api/v1/events/:id`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

### Create Event

**Endpoint:** `POST /api/v1/events`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

**Request Body:**
```json
{
  "event": {
    "title": "Date Night",
    "description": "Dinner at Italian restaurant",
    "starts_at": "2024-01-20T19:00:00Z",
    "ends_at": "2024-01-20T21:00:00Z",
    "all_day": false,
    "location": "Italian Restaurant",
    "category": "date",
    "color": "#FF5733",
    "requires_response": true,
    "recurrence_rule": null
  }
}
```

### Update Event

**Endpoint:** `PATCH /api/v1/events/:id`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

### Delete Event

**Endpoint:** `DELETE /api/v1/events/:id`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

### Respond to Event

**Endpoint:** `POST /api/v1/events/:id/respond`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

**Request Body:**
```json
{
  "status": "accepted"
}
```

Status options: `pending`, `accepted`, `declined`

## Settlements Endpoints

### List Settlements

**Endpoint:** `GET /api/v1/settlements`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

**Query Parameters:**
- `start_date` (optional): Filter by start date
- `end_date` (optional): Filter by end date

### Get Single Settlement

**Endpoint:** `GET /api/v1/settlements/:id`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

### Create Settlement

**Endpoint:** `POST /api/v1/settlements`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

**Request Body:**
```json
{
  "settlement": {
    "payer_id": 1,
    "payee_id": 2,
    "amount_cents": 5000,
    "settled_on": "2024-01-15",
    "notes": "Payment for shared expenses"
  }
}
```

### Update Settlement

**Endpoint:** `PATCH /api/v1/settlements/:id`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

### Delete Settlement

**Endpoint:** `DELETE /api/v1/settlements/:id`

**Headers:** `Authorization: Bearer YOUR_JWT_TOKEN`

## Error Responses

All endpoints may return the following error responses:

### 400 Bad Request
```json
{
  "error": "Parameter missing or invalid"
}
```

### 401 Unauthorized
```json
{
  "error": "Unauthorized"
}
```

### 403 Forbidden
```json
{
  "error": "No couple associated with this user"
}
```

### 404 Not Found
```json
{
  "error": "Record not found"
}
```

### 422 Unprocessable Entity
```json
{
  "errors": [
    "Name can't be blank",
    "Email has already been taken"
  ]
}
```

## Rate Limiting

Currently, there are no rate limits on the API. This may change in future versions.

## CORS

The API supports Cross-Origin Resource Sharing (CORS) for all origins during development. In production, you should configure specific allowed origins in `config/initializers/cors.rb`.

## Versioning

The current API version is v1. All endpoints are prefixed with `/api/v1/`.

## Support

For issues or questions, please contact support or refer to the main application documentation.
