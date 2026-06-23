const { randomUUID } = require('crypto');
const { pool } = require('../config/db');

async function getAllCategories() {
  const result = await pool.query(
    'SELECT id, name, slug, created_at FROM categories ORDER BY name ASC'
  );
  return result.rows;
}

async function getCategoryById(id) {
  const result = await pool.query(
    'SELECT id, name, slug FROM categories WHERE id = $1',
    [id]
  );
  return result.rows[0] || null;
}

async function createCategory({ name, slug }) {
  const id = randomUUID();
  const result = await pool.query(
    `INSERT INTO categories (id, name, slug)
     VALUES ($1, $2, $3)
     RETURNING id, name, slug, created_at`,
    [id, name, slug]
  );
  return result.rows[0];
}

async function updateCategory(id, updates) {
  const fields = Object.entries(updates)
    .filter(([, value]) => value !== undefined)
    .map(([key], index) => `${key} = $${index + 2}`);

  if (!fields.length) return null;

  const values = [id, ...Object.values(updates).filter((value) => value !== undefined)];

  const result = await pool.query(
    `UPDATE categories SET ${fields.join(', ')} WHERE id = $1 RETURNING id, name, slug, created_at`,
    values
  );
  return result.rows[0] || null;
}

async function deleteCategory(id) {
  await pool.query('DELETE FROM categories WHERE id = $1', [id]);
}

module.exports = {
  getAllCategories,
  getCategoryById,
  createCategory,
  updateCategory,
  deleteCategory,
};
