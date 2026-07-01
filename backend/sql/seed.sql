INSERT INTO users (id, name, email, password_hash, role)
VALUES (
  gen_random_uuid(),
  'Ad',
  '.....',
  '$2.........................',
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
