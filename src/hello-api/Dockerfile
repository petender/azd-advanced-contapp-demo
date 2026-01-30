FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --production

COPY app.js ./

# Version can be set at build time or runtime
ARG APP_VERSION=v1
ENV APP_VERSION=${APP_VERSION}
ENV PORT=3000

EXPOSE 3000

CMD ["node", "app.js"]
