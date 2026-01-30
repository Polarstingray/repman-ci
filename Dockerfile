FROM ubuntu:22.04

RUN apt update && \
    apt install -y --no-install-recommends \
        build-essential \
        git \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# docker build -t local/builder:ubuntu22 .