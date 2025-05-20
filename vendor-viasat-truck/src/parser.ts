import { XMLParser } from 'fast-xml-parser';

export function parseXML(xml: string): any {
  const parser = new XMLParser({ ignoreAttributes: false });
  return parser.parse(xml);
}
