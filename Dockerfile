FROM swift:latest

COPY ./ /app/

RUN apt-get update
RUN apt-get install -y openssl libssl-dev libz-dev libcurl4-openssl-dev
RUN apt-get install -y redis-server

RUN mkdir -p /usr/local/var/db/redis/
WORKDIR /app
RUN swift build

EXPOSE 8080

CMD bash /app/run.sh