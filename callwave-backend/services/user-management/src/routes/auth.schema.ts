import { z } from 'zod';
import { validateMatricule, formatMatricule } from '../utils/matricule.js';

export const registerSchema = z.object({
  body: z.object({
    username: z.string().min(3).max(50),
    matricule: z.string().refine(validateMatricule, {
      message: 'Matricule must be exactly 8 characters and start or end with a letter.',
    }),
    password: z.string().min(6),
  }),
});

export const loginSchema = z.object({
  body: z.object({
    matricule: z.string(),
    password: z.string(),
    clientInfo: z.string().optional(),
  }),
});

export const refreshSchema = z.object({
  body: z.object({
    refreshToken: z.string(),
  }),
});
