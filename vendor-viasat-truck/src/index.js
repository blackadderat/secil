import express, { Request, Response } from 'express';
import { parseXML } from './parser';
import { producerConnect } from './kafka-producer';

const app = express();
app.use(express.text({ type: 'application/xml' }));

app.post('/', async (req: Request, res: Response) => {
  try {
    const xmlData = req.body;
    const json = parseXML(xmlData);
    await producerConnect().send(json);
    res.status(200).send('OK');
  } catch (e) {
    res.status(400).send('Error: ' + (e as Error).message);
  }
});

const PORT = process.env.PORT || 7001;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
