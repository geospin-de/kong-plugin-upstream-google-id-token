local json = require "cjson"
local openssl_digest = require "resty.openssl.digest"
local openssl_pkey = require "resty.openssl.pkey"
local table_concat = table.concat
local encode_base64 = ngx.encode_base64
local http = require "resty.http"
local _M = {}

local function get_audience()
    local svc = assert(kong.router.get_service(), "routed by a route without a service")
    local url = svc.protocol .. "://" .. svc.host -- .. ":" .. svc.port
    return url
end

--- base 64 encoding
-- @param input String to base64 encode
-- @return Base64 encoded string
local function b64_encode(input)
    local result = encode_base64(input)
    result = result:gsub("+", "-"):gsub("/", "_"):gsub("=", "")
    return result
end

--- Base64 encode the JWT token
-- @param payload the payload of the token
-- @param key the key to sign the token with
-- @return the encoded JWT token (string)
local function encode_jwt_token(conf, payload, key)
    local header = {
        typ = "JWT",
        alg = "RS256"
    }
    local segments = {b64_encode(json.encode(header)), b64_encode(json.encode(payload))}
    local signing_input = table_concat(segments, ".")
    local digest = openssl_digest.new("sha256")
    assert(digest:update(signing_input))
    local signature = assert(openssl_pkey.new(key):sign(digest))
    segments[#segments + 1] = b64_encode(signature)
    return table_concat(segments, ".")
end

--- Build the JWT token payload to request an id token from google,
--- based on a google service account key
-- @param conf kong configuration
-- @return the JWT payload (table)
local function build_token_request_payload(conf)
    local current_time = ngx.time() -- Much better performance improvement over os.time()
    local payload = {
        iss = google_application_credentials['client_email'],
        aud = google_application_credentials['token_uri'],
        target_audience = get_audience(), -- conf.audience,
        iat = current_time,
        exp = current_time + 60
    }
    return payload
end

--- This is a function that is used to get the id token from the metadata service.
-- @param conf kong configuration
-- @return the id token (string)
local function get_id_token_from_metadata_service(conf)
    local httpc = http.new()
    local res, err = httpc:request_uri(
        "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity?audience=" ..
            get_audience(), {
            method = "GET",
            headers = {
                ["Metadata-Flavor"] = "Google"
            }
        })
    if not res then
        return nil, err
    else
        local id_token = res.body
        kong.log.debug("got new id-token for ", get_audience(), " '", id_token, "'")
        return id_token
    end
end

--- Making a request to the google api to get the id token,
--- based on a given service-account
-- @param conf kong configuration
-- @return the id token (string)
local function get_id_token_via_sa_key(conf)
    local payload = build_token_request_payload(conf)
    local signed_jwt = encode_jwt_token(conf, payload, google_application_credentials['private_key'])
    local httpc = http.new()
    local token_uri = google_application_credentials['token_uri']
    local params = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=" .. signed_jwt
    local res, err = httpc:request_uri(token_uri, {
        method = "POST",
        body = params,
        headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded"
        }
    })
    if not res then
        return nil, err
    else
        local id_token = json.decode(res.body)['id_token']
        kong.log.debug("got new id-token for ", get_audience(), " '", id_token, "'")
        return id_token
    end
end

--- Add the google id token as jwt header to the request
-- @param conf kong configuration
local function add_id_token_jwt_header(conf)
    local token_cache_key = get_audience() -- conf.audience
    local refresh_function = get_id_token_from_metadata_service

    if (google_application_credentials) then
        refresh_function = get_id_token_via_sa_key
    end

    local id_token, err = kong.cache:get(token_cache_key, {
        ttl = conf.id_token_cache_ttl
    }, refresh_function, conf)

    if err then
        kong.log.err(err)
        return kong.response.exit(500, {
            message = "Unexpected error"
        })
    end

    kong.service.request.set_header("Authorization", "Bearer " .. id_token)
end

--- Execute the script
-- @param conf kong configuration
function _M.execute(conf)
    -- kong.log.inspect(google_application_credentials)
    add_id_token_jwt_header(conf)
end

return _M
