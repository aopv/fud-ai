FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json tsconfig.base.json ./
COPY packages ./packages
COPY adapters ./adapters
COPY apps ./apps
RUN npm ci --ignore-scripts
RUN npm run build
RUN npm prune --omit=dev

FROM node:22-alpine AS runtime
ENV NODE_ENV=production
ENV WEB_DIST_DIR=/app/apps/web/dist
WORKDIR /app
COPY --from=build /app /app
USER node
EXPOSE 8787
CMD ["node", "apps/server-node/dist/bin.js"]
