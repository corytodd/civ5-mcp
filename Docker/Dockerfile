FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    lua5.1 \
    liblua5.1-0-dev \
    luarocks \
    gcc \
    libc6-dev \
    python3 && \
    luarocks install luacheck && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY bridge/*.rockspec /tmp
RUN luarocks install --only-deps /tmp/*.rockspec && \
    rm -rf /tmp/*.rockspec

WORKDIR /app
