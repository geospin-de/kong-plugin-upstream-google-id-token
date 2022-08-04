local typedefs = require "kong.db.schema.typedefs"

local PLUGIN_NAME = "upstream-google-id-token"

local schema = {
    name = PLUGIN_NAME,
    fields = {{
        protocols = typedefs.protocols_http
    }, {
        config = {
            type = "record",
            fields = {{
                id_token_cache_ttl = {
                    type = "integer",
                    between = {0, 3600},
                    default = 3600 -- Google ID tokens are issued for one hour validity
                }
            }}
        }
    }}
}

return schema
