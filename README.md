business_logic
=====

Set node rebar3 shell --name business_logic@business.parallelcompute.net --setcookie secret

# Check Riak buckets using API
curl http://RIAK_SERVER_IP:8098/buckets?buckets=true
curl http://RIAK_SERVER_IP:8098/buckets/packages/keys?key=true

# Logger
Add an event handler using gen_event:add_handler(logger_event, logger_event, standard_io) will log to console

Build
-----

    $ rebar3 compile
