# Database Standards

## Context

Database design patterns, query optimization, and data integrity guidelines.

## Schema Design

### Naming Conventions
- Tables: plural, snake_case (`users`, `order_items`)
- Columns: singular, snake_case (`created_at`, `user_id`)
- Primary keys: `id` (auto-increment or UUID)
- Foreign keys: `{table}_id` (`user_id`, `order_id`)
- Indexes: `idx_{table}_{columns}` (`idx_users_email`)

### Standard Columns
```sql
CREATE TABLE users (
  id BIGSERIAL PRIMARY KEY,
  -- domain columns here
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  deleted_at TIMESTAMP WITH TIME ZONE  -- soft delete
);
```

### Data Types
- **IDs**: BIGINT or UUID (prefer BIGINT for performance)
- **Text**: VARCHAR(n) for bounded, TEXT for unbounded
- **Money**: DECIMAL(19,4) or BIGINT (cents)
- **Timestamps**: TIMESTAMP WITH TIME ZONE
- **Booleans**: BOOLEAN (not integers)
- **JSON**: JSONB (not JSON)

## Relationships

### One-to-Many
```sql
-- Posts belong to users
CREATE TABLE posts (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id),
  title VARCHAR(255) NOT NULL,
  content TEXT
);

CREATE INDEX idx_posts_user_id ON posts(user_id);
```

### Many-to-Many
```sql
-- Users have many roles, roles have many users
CREATE TABLE user_roles (
  user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
  role_id BIGINT REFERENCES roles(id) ON DELETE CASCADE,
  granted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  PRIMARY KEY (user_id, role_id)
);
```

### Self-Referential
```sql
-- Categories with parent/child
CREATE TABLE categories (
  id BIGSERIAL PRIMARY KEY,
  parent_id BIGINT REFERENCES categories(id),
  name VARCHAR(100) NOT NULL
);

CREATE INDEX idx_categories_parent_id ON categories(parent_id);
```

## Indexing Strategy

### When to Index
- Foreign keys (always)
- Columns in WHERE clauses
- Columns in ORDER BY clauses
- Columns in JOIN conditions
- Unique constraints

### Index Types
```sql
-- B-tree (default, most common)
CREATE INDEX idx_users_email ON users(email);

-- Partial index
CREATE INDEX idx_active_users ON users(email) WHERE deleted_at IS NULL;

-- Composite index
CREATE INDEX idx_posts_user_created ON posts(user_id, created_at DESC);

-- Full-text search
CREATE INDEX idx_posts_search ON posts USING GIN(to_tsvector('english', title || ' ' || content));
```

### Index Anti-Patterns
- Don't index low-cardinality columns (boolean, status)
- Don't over-index (write performance hit)
- Don't create redundant indexes

## Query Patterns

### Avoid N+1
```ruby
# Bad - N+1 queries
users = User.all
users.each { |u| puts u.posts.count }

# Good - Eager loading
users = User.includes(:posts).all
users.each { |u| puts u.posts.size }
```

### Use Pagination
```sql
-- Cursor-based (preferred for large datasets)
SELECT * FROM posts
WHERE created_at < :cursor
ORDER BY created_at DESC
LIMIT 20;

-- Offset-based (simpler but slower)
SELECT * FROM posts
ORDER BY created_at DESC
LIMIT 20 OFFSET 40;
```

### Batch Operations
```sql
-- Batch insert
INSERT INTO logs (user_id, action, created_at)
VALUES
  (1, 'login', NOW()),
  (2, 'logout', NOW()),
  (3, 'login', NOW());

-- Batch update
UPDATE users
SET last_seen_at = NOW()
WHERE id = ANY(:user_ids);
```

## Data Integrity

### Constraints
```sql
-- Not null
email VARCHAR(255) NOT NULL

-- Unique
UNIQUE(email)

-- Check constraint
CHECK (price >= 0)

-- Foreign key
REFERENCES users(id) ON DELETE CASCADE
```

### Transactions
```sql
BEGIN;
  UPDATE accounts SET balance = balance - 100 WHERE id = 1;
  UPDATE accounts SET balance = balance + 100 WHERE id = 2;
COMMIT;
```

## Migrations

### Best Practices
- One logical change per migration
- Always write both up and down
- Never modify deployed migrations
- Test migrations on production-like data

### Safe Migrations
```ruby
# Adding column (safe)
add_column :users, :nickname, :string

# Adding index (use concurrently in production)
add_index :users, :email, algorithm: :concurrently

# Removing column (deploy code first)
# 1. Deploy code that doesn't use column
# 2. Run migration to remove column
remove_column :users, :legacy_field
```

## Performance

### EXPLAIN ANALYZE
```sql
EXPLAIN ANALYZE
SELECT * FROM posts
WHERE user_id = 123
ORDER BY created_at DESC
LIMIT 20;
```

### Common Optimizations
- Add missing indexes
- Use covering indexes
- Avoid SELECT *
- Use connection pooling
- Consider read replicas
