#! /bin/bash
helm repo add elastic https://helm.elastic.co
helm repo add traefik https://traefik.github.io/charts
helm repo add metallb https://metallb.github.io/metallb
helm repo add openebs https://openebs.github.io/openebs
helm repo add longhorn https://charts.longhorn.io
helm repo add rook-release https://charts.rook.io/release
helm repo update