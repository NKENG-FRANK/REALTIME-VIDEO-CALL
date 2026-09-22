import { Router } from 'express';
import { requireAuth } from '../middlewares/auth.js';
import { getCallHistory, createCallLog, updateCallEnd, markMissedCallAsRead } from '../controllers/calls.controller.js';

const router = Router();

router.use(requireAuth);

router.get('/history', getCallHistory);
router.post('/history', createCallLog);
router.patch('/history/:callId', updateCallEnd);
router.patch('/history/:callId/read', markMissedCallAsRead);

export default router;
