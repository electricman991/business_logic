%%%-------------------------------------------------------------------
%% @doc business_logic public API
%% @end
%%%-------------------------------------------------------------------

-module(business_logic_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    business_logic_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
