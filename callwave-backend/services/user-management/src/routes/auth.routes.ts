import { Router } from 'express';
import { validateRequest } from '../middlewares/validate.js';
import { requireAuth } from '../middlewares/auth.js';
import { registerSchema, loginSchema, refreshSchema } from './auth.schema.js';
import { register, login, refreshToken, logout } from '../controllers/auth.controller.js';

const router = Router();

router.post('/register', validateRequest(registerSchema), register);
router.post('/login', validateRequest(loginSchema), login);
router.post('/refresh', validateRequest(refreshSchema), refreshToken);
router.post('/logout', requireAuth, logout);

export default router;
