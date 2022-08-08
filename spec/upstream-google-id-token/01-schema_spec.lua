local PLUGIN_NAME = "upstream-google-id-token"

-- helper function to validate data against a schema
local validate
do
    local validate_entity = require("spec.helpers").validate_plugin_config_schema
    local plugin_schema = require("kong.plugins." .. PLUGIN_NAME .. ".schema")

    function validate(data)
        return validate_entity(data, plugin_schema)
    end
end

describe(PLUGIN_NAME .. ": (schema)", function()

    it("accepts an empty conf", function()
        local plugin_schema = require("kong.plugins." .. PLUGIN_NAME .. ".schema")
        assert(validate({}, plugin_schema))
    end)

    it("accepts a ttl value for the id token cache", function()
        local ok, err = validate({
            id_token_cache_ttl = 60
        })
        assert.is_nil(err)
        assert.is_truthy(ok)
    end)

    it("accepts only intergers for id_token_cache_ttl", function()
        local ok, err = validate({
            id_token_cache_ttl = "60"
        })
        assert.falsy(ok)
        assert.same({
            id_token_cache_ttl = 'expected an integer'
        }, err.config)
    end)

    it("accepts only intergers between 0 and 3600 for id_token_cache_ttl", function()
        local ok, err = validate({
            id_token_cache_ttl = 7200
        })
        assert.falsy(ok)
        assert.same({
            id_token_cache_ttl = 'value should be between 0 and 3600'
        }, err.config)
    end)

end)
