import { Request, Response, NextFunction } from 'express';
import { pool } from '@callwave/database';

export async function getContacts(req: Request, res: Response, next: NextFunction) {
  try {
    const userId = req.user?.userId;
    const { filter } = req.query; // all, favorite, blocked

    let query = `
      SELECT c.id as contact_record_id, c.custom_alias, c.is_favorite, c.is_blocked,
             u.id, u.username, u.matricule, 
             p.first_name, p.last_name, p.display_name, p.department, p.avatar_url,
             pr.current_status, pr.custom_status_message
      FROM user_contacts c
      JOIN users u ON c.contact_user_id = u.id
      JOIN user_profiles p ON u.id = p.user_id
      LEFT JOIN user_presences pr ON u.id = pr.user_id
      WHERE c.owner_user_id = $1
    `;
    const params: any[] = [userId];

    if (filter === 'favorite') {
      query += ` AND c.is_favorite = TRUE AND c.is_blocked = FALSE`;
    } else if (filter === 'blocked') {
      query += ` AND c.is_blocked = TRUE`;
    } else {
      query += ` AND c.is_blocked = FALSE`;
    }

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (error) {
    next(error);
  }
}

export async function addContact(req: Request, res: Response, next: NextFunction) {
  try {
    const ownerUserId = req.user?.userId;
    const { contactUserId, customAlias } = req.body;

    if (ownerUserId === contactUserId) {
      return res.status(400).json({ error: 'Cannot add yourself as a contact' });
    }

    // Verify contact exists
    const contactExists = await pool.query('SELECT id FROM users WHERE id = $1', [contactUserId]);
    if (contactExists.rowCount === 0) {
      return res.status(404).json({ error: 'Contact user not found' });
    }

    const result = await pool.query(
      `INSERT INTO user_contacts (owner_user_id, contact_user_id, custom_alias)
       VALUES ($1, $2, $3)
       ON CONFLICT (owner_user_id, contact_user_id) 
       DO UPDATE SET custom_alias = EXCLUDED.custom_alias
       RETURNING *`,
      [ownerUserId, contactUserId, customAlias]
    );

    res.status(201).json({ message: 'Contact added successfully', contact: result.rows[0] });
  } catch (error) {
    next(error);
  }
}

export async function updateContact(req: Request, res: Response, next: NextFunction) {
  try {
    const ownerUserId = req.user?.userId;
    const { contactId } = req.params;
    const { customAlias, isFavorite, isBlocked } = req.body;

    const result = await pool.query(
      `UPDATE user_contacts 
       SET custom_alias = COALESCE($1, custom_alias),
           is_favorite = COALESCE($2, is_favorite),
           is_blocked = COALESCE($3, is_blocked)
       WHERE id = $4 AND owner_user_id = $5
       RETURNING *`,
      [customAlias, isFavorite, isBlocked, contactId, ownerUserId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Contact record not found' });
    }

    res.json({ message: 'Contact updated successfully', contact: result.rows[0] });
  } catch (error) {
    next(error);
  }
}

export async function deleteContact(req: Request, res: Response, next: NextFunction) {
  try {
    const ownerUserId = req.user?.userId;
    const { contactId } = req.params;

    const result = await pool.query(
      'DELETE FROM user_contacts WHERE id = $1 AND owner_user_id = $2 RETURNING id',
      [contactId, ownerUserId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Contact record not found' });
    }

    res.json({ message: 'Contact deleted successfully' });
  } catch (error) {
    next(error);
  }
}
