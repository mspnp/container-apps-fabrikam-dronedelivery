FROM node:23.1-alpine AS base

WORKDIR /app

EXPOSE 80

# ---- install dependencies ----
FROM base AS dependencies

WORKDIR /app
COPY package.json .
COPY package-lock.json .
COPY gulpfile.mjs .
RUN npm set progress=false && npm config set depth 0
RUN npm install --omit=dev
RUN cp -R node_modules prod_node_modules

# ---- build ----
FROM dependencies AS build
WORKDIR /app
COPY package-lock.json .
RUN npm install
COPY tsconfig.json .
COPY app app/.
RUN  npm run build

# ---- runtime ----
FROM base AS runtime

WORKDIR /app
COPY --from=dependencies /app/prod_node_modules ./node_modules
COPY --from=build /app/.bin/app .

ENTRYPOINT ["node", "--require", "./telemetry.cjs", "main.js"]
