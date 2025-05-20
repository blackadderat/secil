// vendor-viasat-truck/src/index.ts
import { producerConnect } from './kafka-producer';

async function main() {
  const producer = await producerConnect();
  console.log('Producer connected!');

  // Hier kannst du zum Testen einmalig eine Nachricht senden:
  await producer.send({ msg: 'Hello from Viasat Truck Adapter!' });

  // Optional: Endlosschleife, um das Container-Leben zu halten
  setInterval(() => {}, 10000);
}

main();
