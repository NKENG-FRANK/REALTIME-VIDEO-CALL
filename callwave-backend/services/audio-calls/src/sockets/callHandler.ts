import { Server, Socket } from 'socket.io';
import { publishCallEvent } from '../utils/rabbitmq.js';
import { redis } from '@callwave/redis';
import { randomUUID } from 'crypto';

export function registerCallHandlers(io: Server, socket: Socket) {
  const userId = socket.data.userId;

  // On connection, register presence in Redis for routing
  redis.hset('audio:presence', userId, socket.id);
  socket.join(`user:${userId}`); // Allow targeting specific users
  
  socket.on('disconnect', async () => {
    // Only remove if this specific socket is the one registered
    const currentSocket = await redis.hget('audio:presence', userId);
    if (currentSocket === socket.id) {
      await redis.hdel('audio:presence', userId);
    }
  });

  socket.on('keep_alive', () => {
    // Ping to keep the connection alive
    socket.emit('keep_alive_ack');
  });

  // Call Lifecycle
  socket.on('call:initiate', async (data: { calleeId: string, groupTitle?: string, callType: string }) => {
    const { calleeId, groupTitle, callType } = data;
    
    // In a real scenario, we might create a room ID here
    const roomId = randomUUID();
    
    // Check if callee is online
    const calleeSocketId = await redis.hget('audio:presence', calleeId);
    
    if (calleeSocketId) {
      // Ring the callee
      io.to(`user:${calleeId}`).emit('call:incoming', {
        callerId: userId,
        roomId,
        callType,
        groupTitle
      });
      
      socket.emit('call:ringing', { roomId, calleeId });
    } else {
      // Callee is offline, push to RabbitMQ for missed call log
      socket.emit('call:failed', { reason: 'offline', calleeId });
      
      await publishCallEvent('call.missed', {
        roomId,
        callType,
        callerId: userId,
        participantIds: [userId, calleeId],
        groupTitle
      });
    }
  });

  socket.on('call:accept', async (data: { roomId: string, callerId: string }) => {
    const { roomId, callerId } = data;
    
    // Notify caller that call was accepted
    io.to(`user:${callerId}`).emit('call:accepted', {
      roomId,
      calleeId: userId
    });
    
    // Join WebRTC signaling room
    socket.join(roomId);
    
    // Optionally have caller join the room as well (they might do this in response to call:accepted)
  });

  socket.on('call:reject', async (data: { roomId: string, callerId: string, callType: string }) => {
    const { roomId, callerId, callType } = data;
    
    io.to(`user:${callerId}`).emit('call:rejected', { calleeId: userId, roomId });
    
    // Push event to RabbitMQ
    await publishCallEvent('call.rejected', {
      roomId,
      callType,
      callerId,
      participantIds: [callerId, userId]
    });
  });

  socket.on('call:cancel', (data: { roomId: string, calleeId: string }) => {
    const { roomId, calleeId } = data;
    io.to(`user:${calleeId}`).emit('call:cancelled', { roomId, callerId: userId });
  });

  socket.on('call:end', async (data: { roomId: string, durationSeconds: number, status: string }) => {
    const { roomId, durationSeconds, status } = data;
    
    // Broadcast end to others in the room
    socket.to(roomId).emit('call:ended', { roomId, userId });
    socket.leave(roomId);
    
    await publishCallEvent('call.completed', {
      roomId,
      durationSeconds,
      status
    });
  });

  // WebRTC Signaling
  socket.on('webrtc:offer', (data: { calleeId: string, offer: any, roomId: string }) => {
    // Send offer directly to callee
    io.to(`user:${data.calleeId}`).emit('webrtc:offer', {
      callerId: userId,
      offer: data.offer,
      roomId: data.roomId
    });
  });

  socket.on('webrtc:answer', (data: { callerId: string, answer: any, roomId: string }) => {
    io.to(`user:${data.callerId}`).emit('webrtc:answer', {
      calleeId: userId,
      answer: data.answer,
      roomId: data.roomId
    });
  });

  socket.on('webrtc:ice_candidate', (data: { targetId: string, candidate: any, roomId: string }) => {
    io.to(`user:${data.targetId}`).emit('webrtc:ice_candidate', {
      senderId: userId,
      candidate: data.candidate,
      roomId: data.roomId
    });
  });
}
