# TrustTunnel Docker

Unofficial Docker image for the [TrustTunnel](https://github.com/TrustTunnel/TrustTunnel) endpoint.

The image contains:

- `trusttunnel_endpoint`
- `setup_wizard`

The default working directory is `/config`. With no command, the container runs:

```sh
trusttunnel_endpoint vpn.toml hosts.toml
```

## Run

Create endpoint config files first:

```sh
mkdir -p config
docker run --rm -it -v "$(pwd)/config:/config" fahaddz/trusttunnel setup_wizard
```

Then start the endpoint:

```sh
docker run -d \
  --name trusttunnel \
  -p 443:8443/tcp \
  -p 443:8443/udp \
  -v "$(pwd)/config:/config" \
  fahaddz/trusttunnel
```

For that port mapping, set the TrustTunnel listen address to `0.0.0.0:8443`.

## Pass TrustTunnel Arguments

Arguments are passed to `trusttunnel_endpoint`. For example:

```sh
docker run --rm -v "$(pwd)/config:/config" fahaddz/trusttunnel --version
docker run --rm -v "$(pwd)/config:/config" fahaddz/trusttunnel --loglvl debug
docker run --rm -v "$(pwd)/config:/config" fahaddz/trusttunnel -c username -a vpn.example.com --format deeplink
```

Use custom config file names by putting them first:

```sh
docker run --rm -v "$(pwd)/config:/config" fahaddz/trusttunnel custom-vpn.toml custom-hosts.toml --loglvl debug
```

Run `setup_wizard` directly:

```sh
docker run --rm -it -v "$(pwd)/config:/config" fahaddz/trusttunnel setup_wizard --help
```

## Build Locally

```sh
docker build -t fahaddz/trusttunnel:latest .
```

Pin a specific TrustTunnel release if needed:

```sh
docker build --build-arg TT_VERSION=1.0.33 -t fahaddz/trusttunnel:1.0.33 .
```

The Dockerfile supports the release archive architectures published by TrustTunnel:

- `linux/amd64`
- `linux/arm64`
