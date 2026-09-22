import { Channel } from 'amqplib';
import { connectRabbitMQ, createEventsChannel, publishEvent as rawPublish } from '@callwave/rabbitmq';

let rabbitChannel: Channel | null = null;

export async function initRabbitMQ() {
  try {
    const conn = await connectRabbitMQ();
    rabbitChannel = await createEventsChannel(conn);
    console.log('RabbitMQ connected in audio-calls');
  } catch (error) {
    console.error('Failed to connect to RabbitMQ:', error);
  }
}

export async function publishCallEvent(routingKey: string, payload: any) {
  if (!rabbitChannel) return;
  try {
    await rawPublish(rabbitChannel, routingKey, payload);
  } catch (error) {
    console.error('Failed to publish event:', error);
  }
}
