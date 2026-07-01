const { randomUUID } = require('crypto');
const { pool } = require('../config/db');

const LANG_COL = { en: 'name_en', hi: 'name_hi', mr: 'name_mr' };

function nameCol(lang) {
  // Fall back to name_en for any unknown lang
  return LANG_COL[lang] || 'name_en';
}

async function getAllCategories(lang = 'en') {
  const col = nameCol(lang);
  // Return localised name, falling back to name_en when translation is NULL
  const result = await pool.query(
    `SELECT id,
            COALESCE(${col}, name_en) AS name,
            slug,
            created_at
     FROM categories
     ORDER BY name_en ASC`
  );
  return result.rows;
}

async function getCategoryById(id) {
  const result = await pool.query(
    'SELECT id, name_en AS name, slug FROM categories WHERE id = $1',
    [id]
  );
  return result.rows[0] || null;
}

async function createCategory({ name, slug }) {
  const id = randomUUID();
  const result = await pool.query(
    `INSERT INTO categories (id, name_en, slug)
     VALUES ($1, $2, $3)
     RETURNING id, name_en AS name, slug, created_at`,
    [id, name, slug]
  );
  return result.rows[0];
}

async function updateCategory(id, updates) {
  // Map 'name' field from request to 'name_en' in the DB
  const dbUpdates = {};
  if (updates.name !== undefined) dbUpdates.name_en = updates.name;
  if (updates.name_hi !== undefined) dbUpdates.name_hi = updates.name_hi;
  if (updates.name_mr !== undefined) dbUpdates.name_mr = updates.name_mr;
  if (updates.slug !== undefined) dbUpdates.slug = updates.slug;

  const entries = Object.entries(dbUpdates);
  if (!entries.length) return null;

  const fields = entries.map(([key], index) => `${key} = $${index + 2}`);
  const values = [id, ...entries.map(([, v]) => v)];

  const result = await pool.query(
    `UPDATE categories SET ${fields.join(', ')} WHERE id = $1
     RETURNING id, name_en AS name, slug, created_at`,
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
