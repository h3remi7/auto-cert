#!/bin/sh
set -eu

IMAGE_NAME="${IMAGE_NAME:-auto-cert:latest}"

docker build -t "$IMAGE_NAME" .
