const { pool } = require('../config/db');

/**
 * Updates the user's total time spent in the app for a given day using an UPSERT query.
 */
const recordUsageTime = async (req, res) => {
  try {
    const { usage_date, seconds_used } = req.body;
    const userId = req.user.id;

    if (!usage_date || seconds_used === undefined) {
      return res.status(400).json({
        success: false,
        message: 'usage_date and seconds_used are required parameters'
      });
    }

    if (typeof seconds_used !== 'number' || seconds_used <= 0) {
      return res.status(400).json({
        success: false,
        message: 'seconds_used must be a positive number'
      });
    }

    // UPSERT Query: Insert new row, or if user_id+usage_date exists, add the seconds
    const query = `
      INSERT INTO user_app_usage (user_id, usage_date, time_spent_seconds)
      VALUES ($1, $2, $3)
      ON CONFLICT (user_id, usage_date) 
      DO UPDATE SET time_spent_seconds = user_app_usage.time_spent_seconds + EXCLUDED.time_spent_seconds
      RETURNING *;
    `;

    const values = [userId, usage_date, seconds_used];
    const result = await pool.query(query, values);

    return res.status(200).json({
      success: true,
      message: 'Usage time successfully recorded',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('[Analytics Error] recordUsageTime:', error);
    return res.status(500).json({
      success: false,
      message: 'Internal server error while saving usage analytics',
      error: error.message
    });
  }
};

/**
 * Admin Endpoint: Gets the usage statistics for a specific user.
 */
const getUserUsageStats = async (req, res) => {
  try {
    const { userId } = req.params;

    const query = `
      SELECT usage_date, time_spent_seconds 
      FROM user_app_usage 
      WHERE user_id = $1 
      ORDER BY usage_date DESC
    `;
    
    const result = await pool.query(query, [userId]);

    // Also get lifetime total
    const totalQuery = `
      SELECT SUM(time_spent_seconds) as lifetime_seconds 
      FROM user_app_usage 
      WHERE user_id = $1
    `;
    const totalResult = await pool.query(totalQuery, [userId]);

    return res.status(200).json({
      success: true,
      data: {
        lifetime_seconds: totalResult.rows[0].lifetime_seconds || 0,
        daily_logs: result.rows
      }
    });
  } catch (error) {
    console.error('[Analytics Error] getUserUsageStats:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to retrieve usage stats'
    });
  }
};

/**
 * Admin Endpoint: Gets the global leaderboard of user usage time.
 */
const getGlobalUsageStats = async (req, res) => {
  try {
    const query = `
      SELECT u.id, u.name, u.email, SUM(ua.time_spent_seconds) as total_seconds
      FROM users u
      JOIN user_app_usage ua ON u.id = ua.user_id
      GROUP BY u.id, u.name, u.email
      ORDER BY total_seconds DESC
    `;
    
    const result = await pool.query(query);

    return res.status(200).json({
      success: true,
      data: result.rows
    });
  } catch (error) {
    console.error('[Analytics Error] getGlobalUsageStats:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to retrieve global usage stats'
    });
  }
};

module.exports = {
  recordUsageTime,
  getUserUsageStats,
  getGlobalUsageStats
};
