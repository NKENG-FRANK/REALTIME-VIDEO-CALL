import { Request, Response, NextFunction } from 'express';
import { pool } from '@callwave/database';

export async function getPresence(req: Request, res: Response, next: NextFunction) {
  try {
    const userId = req.user?.userId;

    const result = await pool.query(
      'SELECT current_status, custom_status_message, last_seen_at FROM user_presences WHERE user_id = $1',
      [userId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Presence record not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    next(error);
  }
}

export async function updatePresence(req: Request, res: Response, next: NextFunction) {
  try {
    const userId = req.user?.userId;
    const { status, customMessage } = req.body;

    const result = await pool.query(
      `UPDATE user_presences 
       SET current_status = COALESCE($1, current_status),
           custom_status_message = COALESCE($2, custom_status_message),
           last_seen_at = CURRENT_TIMESTAMP,
           updated_at = CURRENT_TIMESTAMP
       WHERE user_id = $3
       RETURNING current_status, custom_status_message, last_seen_at`,
      [status, customMessage, userId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Presence record not found' });
    }

    res.json({ message: 'Presence updated successfully', presence: result.rows[0] });
  } catch (error) {
    next(error);
  }
}

export async function batchGetPresence(req: Request, res: Response, next: NextFunction) {
  try {
    const { userIds } = req.body;

    if (!Array.isArray(userIds) || userIds.length === 0) {
      return res.status(400).json({ error: 'userIds array is required' });
    }

    const placeholders = userIds.map((_, i) => `$${i + 1}`).join(',');
    const query = `
      SELECT user_id, current_status, custom_status_message, last_seen_at 
      FROM user_presences 
      WHERE user_id IN (${placeholders})
    `;

    const result = await pool.query(query, userIds);

    res.json(result.rows);
  } catch (error) {
    next(error);
  }
}
