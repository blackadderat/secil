import { Kafka, Producer } from 'kafkajs';

const kafka = new Kafka({
  clientId: 'viasat-adapter',
  brokers: ['kafka:9092'],
});

const producer: Producer = kafka.producer();
let connected = false;

export async function producerConnect() {
  if (!connected) {
    await producer.connect();
    connected = true;
  }
  return {
    send: async (msg: any) => {
      await producer.send({
        topic: 'vendor_viasat_truck',
        messages: [
          { value: JSON.stringify(msg) },
        ],
      });
    },
  };
}
