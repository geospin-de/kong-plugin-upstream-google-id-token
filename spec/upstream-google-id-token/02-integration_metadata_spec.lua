local helpers = require "spec.helpers"

local PLUGIN_NAME = "upstream-google-id-token"

for _, strategy in helpers.all_strategies() do
    describe(PLUGIN_NAME .. ": (access using metadata service) [#" .. strategy .. "]", function()
        local client

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
                  server_name metadata.google.internal;
                  listen 80;
                  keepalive_requests 10;
                  location = /computeMetadata/v1/instance/service-accounts/default/identity {
                    echo 'eyJhbGciOiJSUzI1NiIsImtpZCI6ImZkYTEwNjY0NTNkYzlkYzNkZDkzM2E0MWVhNTdkYTNlZjI0MmIwZjciLCJ0eXAiOiJKV1QifQ.eyJhdWQiOiJodHRwOi8vMTI3LjAuMC4xIiwiYXpwIjoicG9ydGFsLXNhQHBsYXlncm91bmQtMjYwMTE2LmlhbS5nc2VydmljZWFjY291bnQuY29tIiwiZW1haWwiOiJwb3J0YWwtc2FAcGxheWdyb3VuZC0yNjAxMTYuaWFtLmdzZXJ2aWNlYWNjb3VudC5jb20iLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwiZXhwIjoxNjYwMDYzOTU0LCJpYXQiOjE2NjAwNjAzNTQsImlzcyI6Imh0dHBzOi8vYWNjb3VudHMuZ29vZ2xlLmNvbSIsInN1YiI6IjExNjY1OTg0OTI0NTU4Nzg3OTcxMSJ9.h8jEvAJn4OgzWgZT0etO5eDKDrS81ejAuoFtN2mmKh0UoyRV-phAx-pySVhKr465WLdXu_S5Y8QpY6Fptw_f-Eaw9W0adhX6Ll54UJf9ftQph6mew8GCa8ul8soWfb1-emKah_0CjDeb2CjfbNkWLJ43Rpu1vwOsM3-FGvHwGbQr2oiXTTiXQbgOz_ncdsCIF1mlch6VPhfKRnedIHpdDnxkg7bDIc-OeFheMJ74IzETWzPLZsZtDf9UZ7h8bkUc-QDi9Mzt3e0jVF3WCTDNz5p_z6pJUUqe8yKf7XXuf6Np_bNtqlRpzyY6LRKPUBrTqWuJLNa9VhSbvVwPmUs2YQ';
                  }
                }
                ]]
                },
                dns_mock = helpers.dns_mock.new()
            }
            fixtures.dns_mock:A{
                name = 'metadata.google.internal',
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
                assert.equal("Bearer eyJhbGciOiJSUzI1NiIsImtpZCI6", string.sub(header_value, 1, 35))
            end)
        end)
    end)
end
