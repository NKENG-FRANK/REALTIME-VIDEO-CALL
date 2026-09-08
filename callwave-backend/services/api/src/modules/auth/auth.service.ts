import argon2 from "argon2";
import jwt from "jsonwebtoken";

import {
  createUser,
  findUserByEmail,
  findUserById,
} from "./auth.repository.js";

import type {
  AuthResponse,
  LoginInput,
  RegisterInput,
} from "./auth.types.js";

const JWT_SECRET = process.env.JWT_SECRET;

if (!JWT_SECRET) {
  throw new Error("JWT_SECRET is not configured");
}

export async function register(
  input: RegisterInput
): Promise<AuthResponse> {
  const existingUser = await findUserByEmail(input.email);

  if (existingUser) {
    throw new Error("User with this email already exists");
  }

  const passwordHash = await argon2.hash(input.password);

  const user = await createUser(input, passwordHash);

  const accessToken = jwt.sign(
    {
      sub: user.id,
      email: user.email,
    },
    JWT_SECRET,
    {
      expiresIn: process.env.JWT_EXPIRES_IN || "7d",
    } as jwt.SignOptions
  );

  return {
    user: {
      id: user.id,
      email: user.email,
      firstName: user.first_name,
      lastName: user.last_name,
      avatarUrl: user.avatar_url,
    },
    accessToken,
  };
}

export async function login(
  input: LoginInput
): Promise<AuthResponse> {
  const user = await findUserByEmail(input.email);

  if (!user) {
    throw new Error("Invalid email or password");
  }

  if (!user.is_active) {
    throw new Error("Account is inactive");
  }

  const passwordValid = await argon2.verify(
    user.password_hash,
    input.password
  );

  if (!passwordValid) {
    throw new Error("Invalid email or password");
  }

  const accessToken = jwt.sign(
    {
      sub: user.id,
      email: user.email,
    },
    JWT_SECRET,
    {
      expiresIn: process.env.JWT_EXPIRES_IN || "7d",
    } as jwt.SignOptions
  );

  return {
    user: {
      id: user.id,
      email: user.email,
      firstName: user.first_name,
      lastName: user.last_name,
      avatarUrl: user.avatar_url,
    },
    accessToken,
  };
}

export async function getCurrentUser(userId: string) {
  const user = await findUserById(userId);

  if (!user) {
    throw new Error("User not found");
  }

  return {
    id: user.id,
    email: user.email,
    firstName: user.first_name,
    lastName: user.last_name,
    avatarUrl: user.avatar_url,
  };
}