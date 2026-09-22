import { Request, Response, NextFunction } from 'express';
import { pool } from '@callwave/database';

export async function getSettings(req: Request, res: Response, next: NextFunction) {
  try {
    const userId = req.user?.userId;

    const result = await pool.query(
      'SELECT theme, language, enable_ringtone, enable_notifications, mute_missed_alerts, auto_mute_mic, auto_turn_off_cam, low_data_mode FROM user_settings WHERE user_id = $1',
      [userId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Settings not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    next(error);
  }
}

export async function updateSettings(req: Request, res: Response, next: NextFunction) {
  try {
    const userId = req.user?.userId;
    const {
      theme,
      language,
      enable_ringtone,
      enable_notifications,
      mute_missed_alerts,
      auto_mute_mic,
      auto_turn_off_cam,
      low_data_mode
    } = req.body;

    const result = await pool.query(
      `UPDATE user_settings 
       SET theme = COALESCE($1, theme),
           language = COALESCE($2, language),
           enable_ringtone = COALESCE($3, enable_ringtone),
           enable_notifications = COALESCE($4, enable_notifications),
           mute_missed_alerts = COALESCE($5, mute_missed_alerts),
           auto_mute_mic = COALESCE($6, auto_mute_mic),
           auto_turn_off_cam = COALESCE($7, auto_turn_off_cam),
           low_data_mode = COALESCE($8, low_data_mode),
           updated_at = CURRENT_TIMESTAMP
       WHERE user_id = $9
       RETURNING theme, language, enable_ringtone, enable_notifications, mute_missed_alerts, auto_mute_mic, auto_turn_off_cam, low_data_mode`,
      [
        theme, language, enable_ringtone, enable_notifications, 
        mute_missed_alerts, auto_mute_mic, auto_turn_off_cam, low_data_mode,
        userId
      ]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Settings not found' });
    }

    res.json({ message: 'Settings updated successfully', settings: result.rows[0] });
  } catch (error) {
    next(error);
  }
}
