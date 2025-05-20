# APISIX Vendor Integration Template

Dieses Repository ist ein schnell lauffähiges Template für Vendor-Datenintegration im IoT/Telematik-Umfeld.  
Es nutzt [Apache APISIX](https://apisix.apache.org/) als zentrales API Gateway, einen modularen Node.js/TypeScript-Adapter und Kafka für Messaging.

## Features

- APISIX API Gateway mit dynamischen Vendor-Routes
- Vendor-Adapter (z.B. für Viasat Truck API) in Node.js/TypeScript
- Kafka Messaging-Layer
- Docker Compose Setup
- Erweiterbar für weitere Vendoren

## Quickstart

```sh
git clone https://github.com/blackadderat/secil.git
cd secil
docker-compose up -d
