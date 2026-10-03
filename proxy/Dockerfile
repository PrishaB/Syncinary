FROM node:22-bookworm-slim

ENV NODE_ENV=production
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY server.js airports.js ./
COPY data/airports.json ./data/airports.json
USER node
EXPOSE 8080
CMD ["node", "server.js"]
