FROM node:19

WORKDIR /usr/src/app
COPY . .

RUN apt update
RUN apt install mecab libmecab-dev mecab-ipadic-utf8 -y
RUN npm install

EXPOSE 8080
CMD [ "node", "main.js" ]