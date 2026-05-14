# syntax=docker/dockerfile:1

ARG DEBIAN_VERSION=bookworm-slim

FROM debian:${DEBIAN_VERSION} AS download
ARG TARGETARCH
ARG TT_VERSION
ARG TT_RELEASE_BASE_URL="https://github.com/TrustTunnel/TrustTunnel/releases/download"

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl tar \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    if [ -z "${TT_VERSION:-}" ]; then \
        TT_VERSION="$(curl -fsSL https://api.github.com/repos/TrustTunnel/TrustTunnel/releases/latest \
            | sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' \
            | head -n 1)"; \
    fi; \
    if [ -z "${TT_VERSION:-}" ] || [ "$TT_VERSION" = "null" ]; then \
        echo "Could not resolve TrustTunnel release version"; \
        exit 1; \
    fi; \
    arch="${TARGETARCH:-$(dpkg --print-architecture)}"; \
    case "$arch" in \
        amd64) tt_arch="x86_64" ;; \
        arm64) tt_arch="aarch64" ;; \
        *) echo "Unsupported architecture: $arch"; exit 1 ;; \
    esac; \
    release_file="trusttunnel-v${TT_VERSION}-linux-${tt_arch}.tar.gz"; \
    curl -fsSL "${TT_RELEASE_BASE_URL}/v${TT_VERSION}/${release_file}" -o /tmp/trusttunnel.tar.gz; \
    mkdir -p /tmp/trusttunnel /out; \
    tar -xzf /tmp/trusttunnel.tar.gz -C /tmp/trusttunnel; \
    install -m 0755 /tmp/trusttunnel/*/trusttunnel_endpoint /out/trusttunnel_endpoint; \
    install -m 0755 /tmp/trusttunnel/*/setup_wizard /out/setup_wizard; \
    install -m 0644 /tmp/trusttunnel/*/LICENSE /out/LICENSE

FROM debian:${DEBIAN_VERSION}

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates iproute2 \
    && mkdir -p /usr/share/doc/trusttunnel \
    && rm -rf /var/lib/apt/lists/*

COPY --from=download /out/trusttunnel_endpoint /usr/local/bin/trusttunnel_endpoint
COPY --from=download /out/setup_wizard /usr/local/bin/setup_wizard
COPY --from=download /out/LICENSE /usr/share/doc/trusttunnel/LICENSE
COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

WORKDIR /config
VOLUME ["/config"]

EXPOSE 443/tcp 443/udp 8443/tcp 8443/udp 80/tcp

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["vpn.toml", "hosts.toml"]
