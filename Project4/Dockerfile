FROM node:18-bullseye

WORKDIR /app

RUN npm install -g @angular/cli@15.0.3

# Copy contents *from* angular-site/ folder *into* container's /app folder
COPY angular-site/package*.json ./
COPY angular-site/ ./

RUN npm install

EXPOSE 4200

CMD ["ng", "serve", "--host", "0.0.0.0"]