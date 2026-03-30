# Package Service

The Package Service is the shipping API for Fabrikam Drone Delivery. It stores package metadata in MongoDB and exposes endpoints used by other workload components to create, update, and query package state.

## What this project includes

- Node.js + TypeScript service built on Koa
- MongoDB-backed repository for package records
- OpenAPI/Swagger endpoint for service contract visibility
- Docker-based local development environment
- Jest unit test suite with coverage reporting

## Local development

### Prerequisites

1. Docker Desktop (or Docker Engine + Compose)
2. Node.js and npm (for local build/test)

### Start with Docker

From this folder, run:

```bash
./up.sh
```

This starts:

- `app` on port `7080` (HTTP)
- `mongo` on port `27017`

To stop:

```bash
./down.sh
```

### Run locally with Node.js

```bash
npm install
npm run build
npm start
```

## Useful scripts

- `npm run build`: compile TypeScript to `.bin/app`
- `npm start`: run in development mode via gulp + nodemon
- `npm test`: run unit tests with coverage
- `npm run clean`: clean build output

## Environment variables

Required at runtime:

- `CONNECTION_STRING`: MongoDB connection string (example: `mongodb://packagedb:27017/local`)
- `COLLECTION_NAME`: MongoDB collection name (example: `packages`)
- `LOG_LEVEL`: logging level (example: `debug`)

Optional:

- `NODE_ENV`: environment name (typically `development` or `production`)

## Quick API check

Create or update a package:

```bash
curl -X PUT --header 'Accept: application/json' 'http://localhost:7080/api/packages/42'
```

Health check:

```bash
curl -X GET 'http://localhost:7080/healthz'
```

## Known startup behavior

On first startup, the service can briefly fail to connect while MongoDB is still booting. This is expected in local Docker runs. The app container is configured with restart-on-failure and normally recovers automatically.
