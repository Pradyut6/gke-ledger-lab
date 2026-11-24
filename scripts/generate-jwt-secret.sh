#!/usr/bin/env bash
set -euo pipefail
umask 077

workdir=$(mktemp -d)
trap 'rm -rf -- "$workdir"' EXIT
openssl genpkey -quiet -algorithm RSA -pkeyopt rsa_keygen_bits:3072 -out "$workdir/jwtRS256.key"
openssl pkey -in "$workdir/jwtRS256.key" -pubout -out "$workdir/jwtRS256.key.pub"
kubectl create secret generic jwt-key --dry-run=client -o yaml \
  --from-file="$workdir/jwtRS256.key" \
  --from-file="$workdir/jwtRS256.key.pub"
