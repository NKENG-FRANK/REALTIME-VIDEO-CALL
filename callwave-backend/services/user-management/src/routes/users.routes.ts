import { Router } from 'express';
import { requireAuth } from '../middlewares/auth.js';
import { getProfile, updateProfile, changePassword, searchUsers } from '../controllers/users.controller.js';

const router = Router();

// All routes require authentication
router.use(requireAuth);

router.get('/profile', getProfile);
router.patch('/profile', updateProfile);
router.post('/change-password', changePassword);
router.get('/search', searchUsers);

export default router;
