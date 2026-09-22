import { Request, Response, NextFunction } from 'express';
import { pool } from '@callwave/database';
import { hashPassword, verifyPassword } from '../utils/password.js';

export async function getProfile(req: Request, res: Response, next: NextFunction) {
  try {
    const userId = req.user?.userId;

    const result = await pool.query(
      `SELECT u.id, u.username, u.matricule, u.role, 
              p.first_name, p.last_name, p.display_name, p.department, 
              p.ministry, p.division, p.position_title, p.office_location, 
              p.avatar_url, p.is_searchable, p.hide_phone_email
       FROM users u
       LEFT JOIN user_profiles p ON u.id = p.user_id
       WHERE u.id = $1`,
      [userId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    next(error);
  }
}

export async function updateProfile(req: Request, res: Response, next: NextFunction) {
  try {
    const userId = req.user?.userId;
    const {
      first_name,
      last_name,
      display_name,
      department,
      ministry,
      division,
      position_title,
      office_location,
      avatar_url,
      is_searchable,
      hide_phone_email
    } = req.body;

    const result = await pool.query(
      `UPDATE user_profiles 
       SET first_name = COALESCE($1, first_name),
           last_name = COALESCE($2, last_name),
           display_name = COALESCE($3, display_name),
           department = COALESCE($4, department),
           ministry = COALESCE($5, ministry),
           division = COALESCE($6, division),
           position_title = COALESCE($7, position_title),
           office_location = COALESCE($8, office_location),
           avatar_url = COALESCE($9, avatar_url),
           is_searchable = COALESCE($10, is_searchable),
           hide_phone_email = COALESCE($11, hide_phone_email),
           updated_at = CURRENT_TIMESTAMP
       WHERE user_id = $12
       RETURNING *`,
      [
        first_name, last_name, display_name, department, ministry, division, 
        position_title, office_location, avatar_url, is_searchable, hide_phone_email, 
        userId
      ]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Profile not found' });
    }

    res.json({ message: 'Profile updated successfully', profile: result.rows[0] });
  } catch (error) {
    next(error);
  }
}

export async function changePassword(req: Request, res: Response, next: NextFunction) {
  try {
    const userId = req.user?.userId;
    const { currentPassword, newPassword } = req.body;

    const userRes = await pool.query('SELECT password_hash FROM users WHERE id = $1', [userId]);

    if (userRes.rowCount === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const isMatch = await verifyPassword(currentPassword, userRes.rows[0].password_hash);
    if (!isMatch) {
      return res.status(401).json({ error: 'Incorrect current password' });
    }

    const hashedNewPassword = await hashPassword(newPassword);

    await pool.query('UPDATE users SET password_hash = $1 WHERE id = $2', [hashedNewPassword, userId]);

    res.json({ message: 'Password updated successfully' });
  } catch (error) {
    next(error);
  }
}

export async function searchUsers(req: Request, res: Response, next: NextFunction) {
  try {
    const { q, limit = 50, offset = 0 } = req.query;

    let queryStr = `
      SELECT u.id, u.username, u.matricule, p.display_name, p.first_name, p.last_name, p.department, p.avatar_url
      FROM users u
      LEFT JOIN user_profiles p ON u.id = p.user_id
      WHERE u.status = 'ACTIVE'
    `;
    const params: any[] = [];

    if (q && typeof q === 'string' && q.trim().length > 0) {
      params.push(`%${q.trim()}%`);
      queryStr += `
        AND (
          u.username ILIKE $1 OR 
          u.matricule ILIKE $1 OR 
          p.display_name ILIKE $1 OR 
          p.first_name ILIKE $1 OR
          p.last_name ILIKE $1 OR
          p.department ILIKE $1
        )
      `;
    }

    params.push(Number(limit), Number(offset));
    queryStr += ` LIMIT $${params.length - 1} OFFSET $${params.length}`;

    const result = await pool.query(queryStr, params);
    res.json(result.rows);
  } catch (error) {
    next(error);
  }
}
