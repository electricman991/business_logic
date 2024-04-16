business_logic
=====

Set node rebar3 shell --name business_logic@business.parallelcompute.net --setcookie secret
curl http://64.23.224.13:8098/buckets?buckets=true
curl http://64.23.224.13:8098/buckets/packages/keys?key=true

# Status 
The location_serv and transfer_serv should be finsihed working on finishing the update and delivered_serv.

Build
-----

    $ rebar3 compile
