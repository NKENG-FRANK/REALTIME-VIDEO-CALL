import { z } from "zod";

export const registerSchema = z.object({
  email: z
    .string()
    .email("Invalid email address")
    .transform((value) => value.toLowerCase().trim()),

  password: z
    .string()
    .min(8, "Password must contain at least 8 characters"),

  firstName: z
    .string()
    .min(1, "First name is required")
    .max(100),

  lastName: z
    .string()
    .min(1, "Last name is required")
    .max(100),
});

export const loginSchema = z.object({
  email: z
    .string()
    .email("Invalid email address")
    .transform((value) => value.toLowerCase().trim()),

  password: z.string().min(1, "Password is required"),
});

export type RegisterRequest = z.infer<typeof registerSchema>;
export type LoginRequest = z.infer<typeof loginSchema>;