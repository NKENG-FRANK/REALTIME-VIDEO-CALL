import type { Request, Response } from "express";

import {
  register,
  login,
  getCurrentUser,
} from "./auth.service.js";

import {
  registerSchema,
  loginSchema,
} from "./auth.validator.js";

export async function registerController(
  req: Request,
  res: Response
) {
  try {
    const input = registerSchema.parse(req.body);

    const result = await register(input);

    res.status(201).json({
      success: true,
      data: result,
    });
  } catch (error) {
    console.error(error);

    if (error instanceof Error) {
      res.status(400).json({
        success: false,
        message: error.message,
      });

      return;
    }

    res.status(500).json({
      success: false,
      message: "Internal server error",
    });
  }
}

export async function loginController(
  req: Request,
  res: Response
) {
  try {
    const input = loginSchema.parse(req.body);

    const result = await login(input);

    res.status(200).json({
      success: true,
      data: result,
    });
  } catch (error) {
    console.error(error);

    if (error instanceof Error) {
      res.status(401).json({
        success: false,
        message: error.message,
      });

      return;
    }

    res.status(500).json({
      success: false,
      message: "Internal server error",
    });
  }
}

export async function meController(
  req: Request,
  res: Response
) {
  try {
    const userId = req.userId;

    if (!userId) {
      res.status(401).json({
        success: false,
        message: "Unauthorized",
      });

      return;
    }

    const user = await getCurrentUser(userId);

    res.status(200).json({
      success: true,
      data: user,
    });
  } catch (error) {
    console.error(error);

    res.status(404).json({
      success: false,
      message:
        error instanceof Error
          ? error.message
          : "User not found",
    });
  }
}