FROM node:22-alpine

ENV DB_CONNECTION=mongodb+srv://Dayveed:Upt0wnk!nq@cluster0.pzicq0x.mongodb.net/reddit-test

WORKDIR /app

COPY package*.json ./

RUN npm ci --omit=dev

COPY . .

EXPOSE 7000

CMD ["npm", "start"]
