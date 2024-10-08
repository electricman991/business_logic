-module(db_api).
-export([put_location_for/3, put_package_for/3, get_location_for/2, get_package_location/2]).

put_location_for(Name_key,Location,Pid)->
	Request=riakc_obj:new(<<"locations">>, Name_key, Location),
	riakc_pb_socket:put(Pid, Request).

put_package_for(Name_key,Package,Pid)->
	Request=riakc_obj:new(<<"packages">>, Name_key, Package),
	riakc_pb_socket:put(Pid, Request).

get_location_for(Name_key,Pid)->
	%Request=riakc_obj:new(<<"locations">>, Name_key, Location),
	riakc_pb_socket:get(Pid, <<"locations">>, Name_key).

get_package_location(Name_key,Pid)->
	riakc_pb_socket:get(Pid, <<"packages">>, Name_key).