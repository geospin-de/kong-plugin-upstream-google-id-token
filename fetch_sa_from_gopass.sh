#!/usr/bin/env sh

gopass show geospin/devops/secrets/kubernetes/playground/portal-sa | base64 -d > spec/fixtures/sa.json
