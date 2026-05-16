# syntax=docker/dockerfile:1

ARG DEBIAN_VERSION=bookworm-slim

FROM debian:${DEBIAN_VERSION} AS download
ARG TARGETARCH
ARG TT_VERSION
ARG TT_SHA256_AMD64
ARG TT_SHA256_ARM64
ARG TT_RELEASE_BASE_URL="https://github.com/TrustTunnel/TrustTunnel/releases/download"
ARG TRUSTTUNNEL_RELEASE_FINGERPRINT="28645AC9776EC4C00BCE2AFC0FE641E7235E2EC6"

# Package versions are intentionally unpinned so scheduled rebuilds pick up
# Debian security updates.
# hadolint ignore=DL3008
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates curl gnupg tar \
    && rm -rf /var/lib/apt/lists/*

COPY trusttunnel-release-key.asc /tmp/trusttunnel-release-key.asc

RUN set -eux; \
    export GNUPGHOME=/tmp/trusttunnel-gnupg; \
    mkdir -p "${GNUPGHOME}"; \
    chmod 0700 "${GNUPGHOME}"; \
    gpg --batch --import /tmp/trusttunnel-release-key.asc; \
    gpg --batch --list-keys --with-colons "${TRUSTTUNNEL_RELEASE_FINGERPRINT}" > /tmp/trusttunnel-key.txt; \
    grep -q "^fpr:::::::::${TRUSTTUNNEL_RELEASE_FINGERPRINT}:" /tmp/trusttunnel-key.txt; \
    if [ -z "${TT_VERSION:-}" ]; then \
        curl -fsSL https://api.github.com/repos/TrustTunnel/TrustTunnel/releases/latest -o /tmp/latest-release.json; \
        TT_VERSION="$(sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' /tmp/latest-release.json)"; \
    fi; \
    if [ -z "${TT_VERSION:-}" ] || [ "$TT_VERSION" = "null" ]; then \
        echo "Could not resolve TrustTunnel release version"; \
        exit 1; \
    fi; \
    arch="${TARGETARCH:-$(dpkg --print-architecture)}"; \
    case "$arch" in \
        amd64) tt_arch="x86_64"; tt_sha256="${TT_SHA256_AMD64:-}" ;; \
        arm64) tt_arch="aarch64"; tt_sha256="${TT_SHA256_ARM64:-}" ;; \
        *) echo "Unsupported architecture: $arch"; exit 1 ;; \
    esac; \
    release_file="trusttunnel-v${TT_VERSION}-linux-${tt_arch}.tar.gz"; \
    curl -fsSL "${TT_RELEASE_BASE_URL}/v${TT_VERSION}/${release_file}" -o /tmp/trusttunnel.tar.gz; \
    if [ -n "${tt_sha256}" ]; then \
        printf '%s  %s\n' "${tt_sha256}" /tmp/trusttunnel.tar.gz > /tmp/trusttunnel.sha256; \
        sha256sum -c /tmp/trusttunnel.sha256; \
    fi; \
    mkdir -p /tmp/trusttunnel /out; \
    tar -xzf /tmp/trusttunnel.tar.gz -C /tmp/trusttunnel; \
    set -- /tmp/trusttunnel/*; \
    release_dir="$1"; \
    test -d "${release_dir}"; \
    gpg --batch --verify "${release_dir}/trusttunnel_endpoint.sig" "${release_dir}/trusttunnel_endpoint"; \
    gpg --batch --verify "${release_dir}/setup_wizard.sig" "${release_dir}/setup_wizard"; \
    install -m 0755 "${release_dir}/trusttunnel_endpoint" /out/trusttunnel_endpoint; \
    install -m 0755 "${release_dir}/setup_wizard" /out/setup_wizard; \
    install -m 0644 "${release_dir}/LICENSE" /out/LICENSE; \
    rm -rf "${GNUPGHOME}" /tmp/latest-release.json /tmp/trusttunnel /tmp/trusttunnel-key.txt /tmp/trusttunnel.sha256 /tmp/trusttunnel.tar.gz

FROM debian:${DEBIAN_VERSION}

# Package versions are intentionally unpinned so scheduled rebuilds pick up
# Debian security updates.
# hadolint ignore=DL3008
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates iproute2 \
    && mkdir -p /config /usr/share/doc/trusttunnel \
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
