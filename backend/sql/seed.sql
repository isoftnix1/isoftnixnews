INSERT INTO users (id, name, email, password_hash, role)
VALUES (
  gen_random_uuid(),
  'Admin User',
  'admin@isoftnix.com',
  '$2a$10$wfFYckZ5KeOdS9XhrcA5D.31E5qWLJZRBSCjKpIEGaJ2etjpJ/9/O',
  'admin'
)
ON CONFLICT (email) DO NOTHING;

INSERT INTO categories (id, name, slug)
VALUES
  (gen_random_uuid(), 'Technology', 'technology'),
  (gen_random_uuid(), 'Business', 'business'),
  (gen_random_uuid(), 'Sports', 'sports'),
  (gen_random_uuid(), 'Entertainment', 'entertainment'),
  (gen_random_uuid(), 'World', 'world')
ON CONFLICT (slug) DO NOTHING;
