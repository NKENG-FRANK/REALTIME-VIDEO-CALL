import { Request, Response, NextFunction } from 'express';
import { pool } from '@callwave/database';

export async function getCallHistory(req: Request, res: Response, next: NextFunction) {
  try {
    const userId = req.user?.userId;
    const { limit = 20, offset = 0 } = req.query;

    const query = `
      SELECT cl.id, cl.group_title, cl.call_type, cl.room_id, cl.started_at, cl.ended_at, 
             cl.duration_seconds, cl.call_status,
             cp.participant_status, cp.is_read as missed_call_read,
             u.id as caller_id, p.display_name as caller_name, p.avatar_url as caller_avatar
      FROM call_logs cl
      JOIN call_participants cp ON cl.id = cp.call_id
      LEFT JOIN users u ON cl.caller_id = u.id
      LEFT JOIN user_profiles p ON u.id = p.user_id
      WHERE cp.user_id = $1
      ORDER BY cl.started_at DESC
      LIMIT $2 OFFSET $3
    `;

    const result = await pool.query(query, [userId, limit, offset]);
    res.json(result.rows);
  } catch (error) {
    next(error);
  }
}

export async function createCallLog(req: Request, res: Response, next: NextFunction) {
  try {
    const callerId = req.user?.userId;
    const { room_id, call_type, group_title, participantIds } = req.body;

    if (!Array.isArray(participantIds) || participantIds.length === 0) {
      return res.status(400).json({ error: 'participantIds array is required' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const callRes = await client.query(
        `INSERT INTO call_logs (room_id, call_type, caller_id, group_title)
         VALUES ($1, $2, $3, $4) RETURNING id`,
        [room_id, call_type, callerId, group_title]
      );
      const callId = callRes.rows[0].id;

      const participantValues = participantIds.map((id, index) => {
        const isCaller = id === callerId;
        const status = isCaller ? 'JOINED' : 'MISSED'; // Missed initially, updated when they answer
        return `('${callId}', '${id}', CURRENT_TIMESTAMP, '${status}', ${isCaller})`;
      }).join(', ');

      await client.query(
        `INSERT INTO call_participants (call_id, user_id, joined_at, participant_status, is_read)
         VALUES ${participantValues}`
      );

      await client.query('COMMIT');
      res.status(201).json({ message: 'Call log created', callId });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } catch (error) {
    next(error);
  }
}

export async function updateCallEnd(req: Request, res: Response, next: NextFunction) {
  try {
    const { callId } = req.params;
    const { durationSeconds, callStatus } = req.body;

    const result = await pool.query(
      `UPDATE call_logs 
       SET ended_at = CURRENT_TIMESTAMP,
           duration_seconds = COALESCE($1, duration_seconds),
           call_status = COALESCE($2, call_status)
       WHERE id = $3
       RETURNING *`,
      [durationSeconds, callStatus, callId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Call log not found' });
    }

    res.json({ message: 'Call log updated', call: result.rows[0] });
  } catch (error) {
    next(error);
  }
}

export async function markMissedCallAsRead(req: Request, res: Response, next: NextFunction) {
  try {
    const userId = req.user?.userId;
    const { callId } = req.params;

    const result = await pool.query(
      `UPDATE call_participants 
       SET is_read = TRUE 
       WHERE call_id = $1 AND user_id = $2 AND participant_status = 'MISSED'`,
      [callId, userId]
    );

    res.json({ message: 'Marked as read', updatedCount: result.rowCount });
  } catch (error) {
    next(error);
  }
}
