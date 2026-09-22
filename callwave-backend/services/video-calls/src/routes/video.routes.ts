import { Router } from 'express';
import { getRoomParticipants, getAllRoomsInfo } from '../mediasoup/roomManager.js';
import { redis } from '@callwave/redis';

const router = Router();

// Check if a specific user is currently in a video room
router.get('/status/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const socketId = await redis.hget('video:presence', userId);
    res.json({
      userId,
      isOnline: !!socketId,
      socketId: socketId || null,
    });
  } catch {
    res.status(500).json({ error: 'Failed to fetch status' });
  }
});

// List participants in a specific room
router.get('/room/:roomId/participants', (req, res) => {
  const { roomId } = req.params;
  const participants = getRoomParticipants(roomId).map((p) => ({
    userId: p.userId,
    producerCount: p.producers.size,
    consumerCount: p.consumers.size,
  }));
  res.json({ roomId, participants });
});

// List all active rooms (admin/debug)
router.get('/rooms', (_req, res) => {
  res.json(getAllRoomsInfo());
});

export default router;
