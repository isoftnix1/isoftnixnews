const { randomUUID } = require('crypto');
const { pool } = require('../config/db');

async function getNewsPage({ page = 1, limit = 10, search = '', categoryId = null }) {
  const offset = (page - 1) * limit;
  const whereClauses = [];
  const values = [];
  let index = 1;

  if (search) {
    whereClauses.push(`(n.title ILIKE $${index} OR n.content ILIKE $${index})`);
    values.push(`%${search}%`);
    index += 1;
  }

  if (categoryId) {
    whereClauses.push(`n.category_id = $${index}`);
    values.push(categoryId);
    index += 1;
  }

  const whereSql = whereClauses.length ? `WHERE ${whereClauses.join(' AND ')}` : '';

  const query = `
    SELECT
      n.id,
      n.title,
      n.content,
      n.image_url,
      n.video_url,
      n.is_published,
      n.created_at,
      n.updated_at,
      c.id AS category_id,
      c.name AS category_name,
      u.id AS author_id,
      u.name AS author_name
    FROM news n
    LEFT JOIN categories c ON n.category_id = c.id
    LEFT JOIN users u ON n.author_id = u.id
    ${whereSql}
    ORDER BY n.created_at DESC
    LIMIT $${index} OFFSET $${index + 1}
  `;

  values.push(limit, offset);

  const [result, countResult] = await Promise.all([
    pool.query(query, values),
    pool.query(`SELECT COUNT(*) FROM news n ${whereSql}`, values.slice(0, values.length - 2))
  ]);

  return {
    items: result.rows,
    total: Number(countResult.rows[0].count),
    page: Number(page),
    limit: Number(limit),
  };
}

async function getNewsById(id) {
  const result = await pool.query(
    `SELECT
      n.id,
      n.title,
      n.content,
      n.image_url,
      n.video_url,
      n.is_published,
      n.created_at,
      n.updated_at,
      c.id AS category_id,
      c.name AS category_name,
      u.id AS author_id,
      u.name AS author_name
    FROM news n
    LEFT JOIN categories c ON n.category_id = c.id
    LEFT JOIN users u ON n.author_id = u.id
    WHERE n.id = $1`,
    [id]
  );
  return result.rows[0] || null;
}

async function createNews({ title, content, authorId, categoryId, imageUrl = null, videoUrl = null, isPublished = true }) {
  const id = randomUUID();
  const result = await pool.query(
    `INSERT INTO news (id, title, content, author_id, category_id, image_url, video_url, is_published)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING *`,
    [id, title, content, authorId, categoryId, imageUrl, videoUrl, isPublished]
  );
  return result.rows[0];
}

async function updateNews(id, updates) {
  const fields = Object.entries(updates)
    .filter(([, value]) => value !== undefined)
    .map(([key], index) => `${key} = $${index + 2}`);

  if (!fields.length) return null;

  const values = [id, ...Object.values(updates).filter((value) => value !== undefined)];

  const result = await pool.query(
    `UPDATE news SET ${fields.join(', ')} WHERE id = $1 RETURNING *`,
    values
  );
  return result.rows[0] || null;
}

async function deleteNews(id) {
  await pool.query('DELETE FROM news WHERE id = $1', [id]);
}

module.exports = {
  getNewsPage,
  getNewsById,
  createNews,
  updateNews,
  deleteNews,
};
