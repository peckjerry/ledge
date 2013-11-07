use Test::Nginx::Socket;
use Cwd qw(cwd);

plan tests => repeat_each() * (blocks() * 3); 

my $pwd = cwd();

$ENV{TEST_LEDGE_REDIS_DATABASE} ||= 1;

our $HttpConfig = qq{
	lua_package_path "$pwd/../lua-resty-http/lib/?.lua;$pwd/lib/?.lua;;";
	init_by_lua "
		ledge_mod = require 'ledge.ledge'
        ledge = ledge_mod:new()
        ledge:config_set('redis_use_sentinel', true)
        ledge:config_set('redis_sentinel_master_name', '$ENV{TEST_LEDGE_SENTINEL_MASTER_NAME}')
        ledge:config_set('redis_sentinels', {
            { host = '127.0.0.1', port = $ENV{TEST_LEDGE_SENTINEL_PORT} }, 
        })
		ledge:config_set('redis_database', $ENV{TEST_LEDGE_REDIS_DATABASE})
        ledge:config_set('upstream_host', '127.0.0.1')
        ledge:config_set('upstream_port', 1984)
	";
};

no_long_string();
run_tests();

__DATA__
=== TEST 1: Prime cache
--- http_config eval: $::HttpConfig
--- config
	location /sentinel_1_prx {
        rewrite ^(.*)_prx$ $1 break;
        content_by_lua '
            ledge:run()
        ';
    }
    location /sentinel_1 {
        content_by_lua '
            ngx.header["Cache-Control"] = "max-age=3600"
            ngx.say("OK")
        ';
    }
--- request
GET /sentinel_1_prx
--- no_error_log
[error]
--- response_body
OK
