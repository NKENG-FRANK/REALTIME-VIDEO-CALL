import { Router } from 'express';
import { requireAuth } from '../middlewares/auth.js';
import { getPresence, updatePresence, batchGetPresence } from '../controllers/presence.controller.js';

const router = Router();

router.use(requireAuth);

router.get('/', getPresence);
router.patch('/', updatePresence);
router.post('/batch', batchGetPresence);

export default router;
