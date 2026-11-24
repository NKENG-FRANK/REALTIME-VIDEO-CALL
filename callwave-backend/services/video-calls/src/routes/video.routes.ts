import { createHmac } from 'node:crypto';
import { Router } from 'express';
import { getRoom } from '../mediasoup/roomManager.js';
import { redis } from '@callwave/redis';
import { requireHttpAuth } from '../middlewares/httpAuth.js';

const router = Router();
router.use(requireHttpAuth);

router.get('/turn-credentials', (req, res) => {
  const secret = process.env.TURN_SHARED_SECRET;
  const urls = process.env.TURN_URLS?.split(',').map((url) => url.trim()).filter(Boolean) ?? [];
  const validUrl = /^turns?:[a-z0-9.\-\[\]:]+(?:\?transport=(?:udp|tcp))?$/i;
  if (!secret || secret.length < 32 || urls.length === 0 || !urls.every((url) => validUrl.test(url))) {
    return res.status(503).json({ error: 'TURN service is not configured' });
  }

  const expiresAt = Math.floor(Date.now() / 1000) + 3600;
  const username = `${expiresAt}:${req.authUserId}`;
  const credential = createHmac('sha1', secret).update(username).digest('base64');
  res.set('Cache-Control', 'no-store');
  res.json({ urls, username, credential, expiresAt });
});

// Check if a specific user is currently in a video room
router.get('/status/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    if (userId !== req.authUserId) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    const isOnline = await redis.hexists('video:presence', userId);
    res.json({
      userId,
      isOnline: !!isOnline,
    });
  } catch {
    res.status(500).json({ error: 'Failed to fetch status' });
  }
});

// List participants in a specific room
router.get('/room/:roomId/participants', (req, res) => {
  const { roomId } = req.params;
  const room = getRoom(roomId);
  if (!room?.participants.has(req.authUserId!)) {
    return res.status(403).json({ error: 'Forbidden' });
  }

  const participants = Array.from(room.participants.values()).map((p) => ({
    userId: p.userId,
    producerCount: p.producers.size,
    consumerCount: p.consumers.size,
  }));
  res.json({ roomId, participants });
});

export default router;
