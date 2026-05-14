#!/bin/sh
set -e

if [ "$#" -gt 0 ]; then
    case "$1" in
        trusttunnel_endpoint|setup_wizard|sh)
            exec "$@"
            ;;
    esac
fi

if [ "$#" -eq 0 ]; then
    set -- vpn.toml hosts.toml
fi

case "${1:-}" in
    -h|--help|-v|--version)
        exec trusttunnel_endpoint "$@"
        ;;
    -*)
        exec trusttunnel_endpoint "$@" vpn.toml hosts.toml
        ;;
    *)
        exec trusttunnel_endpoint "$@"
        ;;
esac
