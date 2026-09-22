import { Router } from 'express';
import { redis } from '@callwave/redis';

const router = Router();

// A simple REST endpoint to check if a user is actively online/available in the audio service
router.get('/status/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    // Check if user has an active socket connection registered in Redis
    const socketId = await redis.hget('audio:presence', userId);
    
    res.json({
      userId,
      isOnline: !!socketId,
      socketId: socketId || null
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch audio status' });
  }
});

export default router;
