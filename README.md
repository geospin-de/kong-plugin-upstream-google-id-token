# kong-plugin-upstream-google-id-token
Kong plugin to do service to service authentication with upstream services running in GCP.

## Overview

This plugin will add a Google ID-Token into the HTTP Header of proxied requests through the Kong gateway. The purpose of this, is to provide service to service authentication and authorization to upstream APIs running in the Google Cloud ([like Google Cloud Run](https://cloud.google.com/run/docs/authenticating/service-to-service)). It is inspired by [Kong Upstream JWT Plugin](https://github.com/Optum/kong-upstream-jwt/).

## Usage

### Enabling the plugin on a Service

```
curl -i -X POST http://kong:8001/services/{service}/plugins/ \
 --data 'name=upstream-google-id-token' \
 --data 'config.id_token_cache_ttl=60'
```

### Config

- `config.id_token_cache_ttl`: How long the ID token should be cached (3600 minutes by default, which is the maximum validity of a Google-issued ID token)

### Running outside of the google cloud

You can call a private service from outside Google Cloud using a downloaded service account key. You should place the key somewere it can be read from the nginx root process. The plugin checks the environemt variable `GOOGLE_APPLICATION_CREDENTIALS` for a path to the key file.

## Supported Kong Releases

Kong >= 2.0

Should work with 1.X but not tested

## Installation

```
luarocks install kong-plugin-upstream-google-id-token
```

## Tests

You need [Pongo](https://github.com/Kong/kong-pongo) to run the tests.

```bash
pongo run
```
Expected output:
```
Kong version: 2.8.1
●●●●●●●●●●
10 successes / 0 failures / 0 errors / 0 pending : 27.130195 seconds
```

## Create and upload rock file to luarocks.org

You can use the **Pongo** environment for this. All you need is an API key, which you can generate after successfully registering on <luarocks.org>.

```bash
pongo shell luarocks upload --api-key <API_KEY> \
  /kong-plugin/kong-plugin-upstream-google-id-token-<VERSION>.rockspec
```

## Maintainers

[Flo](https://github.com/fw8)
