# TrustTunnel Docker

Unofficial Docker image for the
[TrustTunnel](https://github.com/TrustTunnel/TrustTunnel) endpoint.

The image packages the upstream release binaries:

- `trusttunnel_endpoint`
- `setup_wizard`

The default working directory is `/config`, and `/config` is declared as a
volume. With no command, the container runs:

```sh
trusttunnel_endpoint vpn.toml hosts.toml
```

## Runtime User

This image follows the upstream TrustTunnel Dockerfiles and does not set a
`USER`. The container therefore runs as Docker's default user, root.

That is intentional for TrustTunnel because endpoint setups may need to bind
ports `80`/`443`, create or renew certificates, or use optional ICMP forwarding.
If your deployment has stricter requirements, you can still run the container
with a custom `--user`, but then config-file ownership, low ports, certificates,
and ICMP need to be handled by your own runtime settings.

## Quick Start

Create the endpoint config files first:

```sh
mkdir -p config
docker run --rm -it -v "$(pwd)/config:/config" fahaddz/trusttunnel setup_wizard
```

Start the endpoint:

```sh
docker run -d \
  --name trusttunnel \
  --restart unless-stopped \
  -p 443:8443/tcp \
  -p 443:8443/udp \
  -v "$(pwd)/config:/config" \
  fahaddz/trusttunnel
```

For that port mapping, set the TrustTunnel listen address to
`0.0.0.0:8443` in `vpn.toml`.

If you use Let's Encrypt HTTP-01 inside the container, also publish port `80`:

```sh
-p 80:80/tcp
```

ICMP forwarding is not enabled by default. If your TrustTunnel config uses an
`[icmp]` section, add only the extra runtime privileges required by that setup.

## Commands

Arguments are passed to `trusttunnel_endpoint`:

```sh
docker run --rm -v "$(pwd)/config:/config" fahaddz/trusttunnel --version
docker run --rm -v "$(pwd)/config:/config" fahaddz/trusttunnel --loglvl debug
docker run --rm -v "$(pwd)/config:/config" fahaddz/trusttunnel \
  -c username -a vpn.example.com --format deeplink
```

Use custom config file names by putting them first:

```sh
docker run --rm -v "$(pwd)/config:/config" fahaddz/trusttunnel \
  custom-vpn.toml custom-hosts.toml --loglvl debug
```

Run `setup_wizard` directly:

```sh
docker run --rm -it -v "$(pwd)/config:/config" fahaddz/trusttunnel \
  setup_wizard --help
```

## Tags

- `latest` tracks the latest upstream TrustTunnel release and is rebuilt by the
  scheduled workflow.
- `<version>` and `v<version>` point to a specific TrustTunnel release, for
  example `1.0.33` and `v1.0.33`.
- `rebuild-<version>-<date>` is produced by the daily scheduled workflow, for
  example `rebuild-1.0.33-20260516`.

Scheduled builds do not overwrite existing version tags. They always publish
`latest` and the dated rebuild tag. If the upstream latest release is new and
its version tags do not exist yet, the scheduled workflow publishes those tags
once.

Manual workflow runs with a specific `trusttunnel_version` publish only that
release's version tags. They do not move `latest` backward.

## Build Locally

Build the latest upstream release:

```sh
docker build -t fahaddz/trusttunnel:latest .
```

Pin a specific TrustTunnel release:

```sh
docker build --build-arg TT_VERSION=1.0.33 -t fahaddz/trusttunnel:1.0.33 .
```

The Dockerfile supports the Linux release architectures published by
TrustTunnel:

- `linux/amd64`
- `linux/arm64`

## Release Checks

The Docker build imports the pinned TrustTunnel release public key from this
repository and verifies the detached signatures for `trusttunnel_endpoint` and
`setup_wizard` before installing the binaries into the image.

GitHub Actions also:

- resolves the upstream release through the authenticated GitHub API
- checks the SHA256 digest for the upstream amd64 and arm64 release archives
- builds a local amd64 smoke-test image before publishing
- runs `trusttunnel_endpoint --version`
- runs `setup_wizard --help`

If any of those checks fail, the workflow stops before pushing to Docker Hub.
