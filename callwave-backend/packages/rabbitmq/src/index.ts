import amqp, { type Channel, type ChannelModel } from 'amqplib';
import { config } from '@callwave/config';

export const EVENTS_EXCHANGE = 'callwave.events';

export async function connectRabbitMQ(): Promise<ChannelModel> {
  return amqp.connect(config.rabbitmq.url);
}

export async function createEventsChannel(connection: ChannelModel): Promise<Channel> {
  const channel = await connection.createChannel();
  await channel.assertExchange(EVENTS_EXCHANGE, 'topic', { durable: true });
  return channel;
}

export async function publishEvent(
  channel: Channel,
  routingKey: string,
  payload: unknown,
): Promise<boolean> {
  return channel.publish(
    EVENTS_EXCHANGE,
    routingKey,
    Buffer.from(JSON.stringify(payload)),
    { contentType: 'application/json', persistent: true },
  );
}
