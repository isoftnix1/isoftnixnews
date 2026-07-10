const { randomUUID } = require('crypto');
const { pool } = require('../config/db');

async function getNewsPage({ page = 1, limit = 10, search = '', categoryId = null, startDate = null, endDate = null, publishedOnly = false }) {
  const offset = (page - 1) * limit;
  const whereClauses = [];
  const values = [];
  let index = 1;

  if (publishedOnly) {
    whereClauses.push('n.is_published = true');
  }

  if (search) {
    whereClauses.push(`(n.title_en ILIKE $${index} OR n.content_en ILIKE $${index} OR n.title_hi ILIKE $${index} OR n.title_mr ILIKE $${index})`);
    values.push(`%${search}%`);
    index += 1;
  }

  if (categoryId) {
    whereClauses.push(`EXISTS (SELECT 1 FROM news_categories nc WHERE nc.news_id = n.id AND nc.category_id = $${index})`);
    values.push(categoryId);
    index += 1;
  }

  if (startDate) {
    whereClauses.push(`n.created_at >= $${index}`);
    values.push(startDate);
    index += 1;
  }

  if (endDate) {
    // Add 1 day so the entire end date is included (up to midnight of next day)
    whereClauses.push(`n.created_at < ($${index}::date + INTERVAL '1 day')`);
    values.push(endDate);
    index += 1;
  }

  const whereSql = whereClauses.length ? `WHERE ${whereClauses.join(' AND ')}` : '';

  const query = `
    SELECT
      n.id,
      n.title_en,
      n.content_en,
      n.title_hi,
      n.content_hi,
      n.title_mr,
      n.content_mr,
      n.image_url,
      n.video_url,
      n.source_name,
      n.source_url,
      n.is_published,
      n.views_count,
      n.reminder_status,
      n.reminder_sent_count,
      n.published_at,
      n.created_at,
      n.updated_at,
      c.id AS category_id,
      c.name_en AS category_name_en,
      c.name_hi AS category_name_hi,
      c.name_mr AS category_name_mr,
      u.id AS author_id,
      u.name AS author_name,
      (
        SELECT json_agg(json_build_object('id', cat.id, 'name', cat.name_en, 'name_en', cat.name_en, 'name_hi', cat.name_hi, 'name_mr', cat.name_mr))
        FROM news_categories nc
        JOIN categories cat ON nc.category_id = cat.id
        WHERE nc.news_id = n.id
      ) AS categories
    FROM news n
    LEFT JOIN categories c ON n.category_id = c.id
    LEFT JOIN users u ON n.author_id = u.id
    ${whereSql}
    ORDER BY n.created_at DESC
    LIMIT $${index} OFFSET $${index + 1}
  `;

  values.push(limit, offset);

  let countWhereSql = whereSql;
  let countValues = values.slice(0, values.length - 2);
  let countQuery = `SELECT COUNT(*) FROM news n ${countWhereSql}`;

  const [result, countResult] = await Promise.all([
    pool.query(query, values),
    pool.query(countQuery, countValues)
  ]);

  return {
    items: result.rows,
    total: Number(countResult.rows[0].count),
    page: Number(page),
    limit: Number(limit),
  };
}

async function getNewsById(id, { publishedOnly = false } = {}) {
  const result = await pool.query(
    `SELECT
      n.id,
      n.title_en,
      n.content_en,
      n.title_hi,
      n.content_hi,
      n.title_mr,
      n.content_mr,
      n.image_url,
      n.video_url,
      n.source_name,
      n.source_url,
      n.is_published,
      n.views_count,
      n.reminder_status,
      n.reminder_sent_count,
      n.published_at,
      n.created_at,
      n.updated_at,
      c.id AS category_id,
      c.name_en AS category_name_en,
      c.name_hi AS category_name_hi,
      c.name_mr AS category_name_mr,
      u.id AS author_id,
      u.name AS author_name,
      (
        SELECT json_agg(json_build_object('id', cat.id, 'name', cat.name_en, 'name_en', cat.name_en, 'name_hi', cat.name_hi, 'name_mr', cat.name_mr))
        FROM news_categories nc
        JOIN categories cat ON nc.category_id = cat.id
        WHERE nc.news_id = n.id
      ) AS categories
    FROM news n
    LEFT JOIN categories c ON n.category_id = c.id
    LEFT JOIN users u ON n.author_id = u.id
    WHERE n.id = $1${publishedOnly ? ' AND n.is_published = true' : ''}`,
    [id]
  );
  return result.rows[0] || null;
}

async function createNews({ title_en, content_en, title_hi, content_hi, title_mr, content_mr, authorId, categoryIds, imageUrl = null, videoUrl = null, source_name = null, source_url = null, isPublished = true, publishedAt = null }) {
  const id = randomUUID();
  const primaryCategoryId = categoryIds && categoryIds.length > 0 ? categoryIds[0] : null;
  
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    
    const result = await client.query(
      `INSERT INTO news (id, title_en, content_en, title_hi, content_hi, title_mr, content_mr, author_id, category_id, image_url, video_url, source_name, source_url, is_published, published_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, CASE WHEN $14 = TRUE THEN NOW() ELSE $15 END)
       RETURNING *`,
      [id, title_en, content_en, title_hi, content_hi, title_mr, content_mr, authorId, primaryCategoryId, imageUrl, videoUrl, source_name, source_url, isPublished, publishedAt]
    );
    
    if (categoryIds && categoryIds.length > 0) {
      for (const catId of categoryIds) {
        await client.query(
          `INSERT INTO news_categories (news_id, category_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
          [id, catId]
        );
      }
    }
    
    await client.query('COMMIT');
    return result.rows[0];
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
}

async function updateNews(id, updates, categoryIds = null) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    
    if (categoryIds && categoryIds.length > 0) {
      updates.category_id = categoryIds[0];
    }
    
    const fields = Object.entries(updates)
      .filter(([, value]) => value !== undefined)
      .map(([key], index) => `${key} = $${index + 2}`);

    let updatedNews = null;
    if (fields.length > 0) {
      if (updates.is_published === true && !updates.published_at) {
        fields.push(`published_at = COALESCE(published_at, NOW())`);
      }
      
      const values = [id, ...Object.values(updates).filter((value) => value !== undefined)];
      const result = await client.query(
        `UPDATE news SET ${fields.join(', ')} WHERE id = $1 RETURNING *`,
        values
      );
      updatedNews = result.rows[0] || null;
    }
    
    if (categoryIds !== null) {
      await client.query(`DELETE FROM news_categories WHERE news_id = $1`, [id]);
      if (categoryIds.length > 0) {
        for (const catId of categoryIds) {
          await client.query(
            `INSERT INTO news_categories (news_id, category_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
            [id, catId]
          );
        }
      }
    }
    
    await client.query('COMMIT');
    return updatedNews || await getNewsById(id);
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
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
