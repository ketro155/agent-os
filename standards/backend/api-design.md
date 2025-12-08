# API Design Standards

## Context

RESTful API design patterns for consistent, predictable backend interfaces.

## URL Structure

### Resource Naming
```
GET    /users              # List users
GET    /users/:id          # Get single user
POST   /users              # Create user
PUT    /users/:id          # Update user (full)
PATCH  /users/:id          # Update user (partial)
DELETE /users/:id          # Delete user
```

### Nested Resources
```
GET    /users/:id/posts    # User's posts
POST   /users/:id/posts    # Create post for user
GET    /posts/:id/comments # Post's comments
```

### Naming Conventions
- Use plural nouns: `/users`, not `/user`
- Use kebab-case: `/user-profiles`, not `/userProfiles`
- Avoid verbs: `/users`, not `/getUsers`
- Keep URLs shallow (max 2-3 levels)

## Request/Response Format

### Request Headers
```
Content-Type: application/json
Authorization: Bearer <token>
Accept: application/json
X-Request-ID: <uuid>
```

### Response Structure
```json
// Success response
{
  "data": {
    "id": "123",
    "name": "John Doe",
    "email": "john@example.com"
  }
}

// List response with pagination
{
  "data": [...],
  "meta": {
    "total": 100,
    "page": 1,
    "per_page": 20,
    "total_pages": 5
  }
}

// Error response
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input data",
    "details": [
      {
        "field": "email",
        "message": "Invalid email format"
      }
    ]
  }
}
```

## HTTP Status Codes

### Success
- `200 OK` - Successful GET, PUT, PATCH
- `201 Created` - Successful POST (return created resource)
- `204 No Content` - Successful DELETE

### Client Errors
- `400 Bad Request` - Invalid request data
- `401 Unauthorized` - Missing/invalid authentication
- `403 Forbidden` - Authenticated but not authorized
- `404 Not Found` - Resource doesn't exist
- `409 Conflict` - State conflict (duplicate, etc.)
- `422 Unprocessable Entity` - Validation failed

### Server Errors
- `500 Internal Server Error` - Unexpected server error
- `503 Service Unavailable` - Temporary overload/maintenance

## Authentication

### Bearer Token
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
```

### API Key (for service-to-service)
```
X-API-Key: sk_live_abc123...
```

### Token Refresh
```
POST /auth/refresh
{
  "refresh_token": "..."
}
```

## Pagination

### Cursor-Based (Preferred)
```
GET /posts?cursor=abc123&limit=20

Response:
{
  "data": [...],
  "meta": {
    "next_cursor": "def456",
    "has_more": true
  }
}
```

### Offset-Based
```
GET /posts?page=2&per_page=20

Response:
{
  "data": [...],
  "meta": {
    "total": 100,
    "page": 2,
    "per_page": 20,
    "total_pages": 5
  }
}
```

## Filtering & Sorting

### Query Parameters
```
GET /users?status=active&role=admin
GET /posts?created_after=2024-01-01
GET /products?price_min=10&price_max=100
```

### Sorting
```
GET /users?sort=created_at:desc
GET /posts?sort=title:asc,created_at:desc
```

### Field Selection
```
GET /users?fields=id,name,email
```

## Rate Limiting

### Headers
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1609459200
```

### Response (429)
```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Too many requests",
    "retry_after": 60
  }
}
```

## Versioning

### URL Versioning (Preferred)
```
/api/v1/users
/api/v2/users
```

### Header Versioning (Alternative)
```
Accept: application/vnd.api+json; version=2
```

## Documentation

Every API should have:
- OpenAPI/Swagger specification
- Example requests and responses
- Authentication instructions
- Error code reference
- Rate limiting details
