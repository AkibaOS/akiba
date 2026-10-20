# //! Pinned Linux Native Build Environment

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    make \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir /tmp/akiba-zig-input /opt/zig && \
    curl --fail --show-error --location --proto '=https' --tlsv1.2 \
        https://ziglang.org/download/0.15.2/zig-x86_64-linux-0.15.2.tar.xz \
        --output /tmp/akiba-zig-input/zig.tar.xz && \
    printf '%s  %s\n' \
        02aa270f183da276e5b5920b1dac44a63f1a49e55050ebde3aecc9eb82f93239 \
        /tmp/akiba-zig-input/zig.tar.xz | sha256sum --check --strict - && \
    tar --extract --xz --file /tmp/akiba-zig-input/zig.tar.xz \
        --directory /opt/zig --strip-components=1 && \
    ln -s /opt/zig/zig /usr/local/bin/zig && \
    rm -rf /tmp/akiba-zig-input

WORKDIR /akiba
