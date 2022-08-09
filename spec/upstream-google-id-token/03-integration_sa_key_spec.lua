local helpers = require "spec.helpers"

local PLUGIN_NAME = "upstream-google-id-token"

for _, strategy in helpers.all_strategies() do
    describe(PLUGIN_NAME .. ": (access) [#" .. strategy .. "]", function()
        local client

        helpers.setenv("GOOGLE_APPLICATION_CREDENTIALS", "/kong-plugin/spec/fixtures/sa.json")

        lazy_setup(function()

            local bp = helpers.get_db_utils(strategy == "off" and "postgres" or strategy, nil, {PLUGIN_NAME})

            -- Inject a test route. No need to create a service, there is a default
            -- service which will echo the request.
            local route1 = bp.routes:insert({
                hosts = {"test1.com"}
            })
            -- add the plugin to test to the route we created
            bp.plugins:insert{
                name = PLUGIN_NAME,
                route = {
                    id = route1.id
                },
                config = {
                    id_token_cache_ttl = 60
                }
            }

            -- start kong
            assert(helpers.start_kong({
                -- set the strategy
                database = strategy,
                -- use the custom test template to create a local mock server
                nginx_conf = "spec/fixtures/custom_nginx.template",
                -- make sure our plugin gets loaded
                plugins = "bundled," .. PLUGIN_NAME,
                -- write & load declarative config, only if 'strategy=off'
                declarative_config = strategy == "off" and helpers.make_yaml_file() or nil
            }))
        end)

        lazy_teardown(function()
            helpers.stop_kong(nil, true)
        end)

        before_each(function()
            client = helpers.proxy_client()
        end)

        after_each(function()
            if client then
                client:close()
            end
        end)

        describe("request", function()

            it("gets an 'Authorization' header", function()
                local r = client:get("/request", {
                    headers = {
                        host = "test1.com"
                    }
                })
                -- validate that the request succeeded, response status 200
                assert.response(r).has.status(200)
                -- now check the request (as echoed by mockbin) to have the header
                local header_value = assert.request(r).has.header("Authorization")
                -- validate the value of that header
                -- Bearer should start with {"alg":"RS256","kid":  encoded in base64
                assert.equal("Bearer eyJhbGciOiJSUzI1NiIsImtpZCI6", string.sub(header_value, 1, 35))
            end)
        end)
    end)
end
