local helpers = require "spec.helpers"

local PLUGIN_NAME = "upstream-google-id-token"

for _, strategy in helpers.all_strategies() do
    describe(PLUGIN_NAME .. ": (access) [#" .. strategy .. "]", function()
        local client

        helpers.setenv("GOOGLE_APPLICATION_CREDENTIALS", "/kong-plugin/spec/fixtures/fake-service-account.json")

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

            local fixtures = {
                http_mock = {
                    metadata = [[
              server {
                server_name oauth2.googleapis.com;
                listen 80;
                keepalive_requests 10;
                location = /token {
                  default_type application/json;
                  echo '{"id_token":"eyJhbGciOiJIUzI1NiIsImtpZCI6ImZkYTEwNjY0NTNkYzlkYzNkZDkzM2E0MWVhNTdkYTNlZjI0MmIwZjciLCJ0eXAiOiJKV1QifQ.eyJhdWQiOiJodHRwOi8vMTI3LjAuMC4xIiwiYXpwIjoiZmFrZS1zZXJ2aWNlLWFjY291bkBwcm9qZWN0LWlkLmlhbS5nc2VydmljZWFjY291bnQuY29tIiwiZW1haWwiOiJmYWtlLXNlcnZpY2UtYWNjb3VudEBwcm9qZWN0LWlkLmlhbS5nc2VydmljZWFjY291bnQuY29tIiwiZW1haWxfdmVyaWZpZWQiOnRydWUsImV4cCI6MTY2MDA2Mzk1NCwiaWF0IjoxNjYwMDYwMzU0LCJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJzdWIiOiI3NDExNzQxMTc0MTE3NDExNzQxMSJ9.aa5tPd_v-hrjDqlT-IlhBGYNT0tes3VvzjixRryc-t8"}';
                }
              }
              ]]
                },
                dns_mock = helpers.dns_mock.new()
            }
            fixtures.dns_mock:A{
                name = 'oauth2.googleapis.com',
                address = '127.0.0.1'
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
            }, nil, nil, fixtures))
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
                assert.equal("Bearer eyJhbGciOiJIUzI1NiIsImtpZCI6", string.sub(header_value, 1, 35))
            end)
        end)
    end)
end
