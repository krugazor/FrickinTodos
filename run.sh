#!/bin/bash

redis-server /app/redis.conf 2>&1 > /dev/null &
swift run