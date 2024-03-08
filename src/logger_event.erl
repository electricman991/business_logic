-module(logger_event).
-behaviour(gen_event).

%% Supervisor Callbacks
-export([init/1,terminate/3,code_change/2,start/0]).
%% event Callbacks
-export([handle_event/2,handle_info/2,handle_call/2]).

%%%===================================================================
%%% Mandatory callback functions
%%%===================================================================

start() ->
    gen_event:start_link({local, logger_event}).
terminate(_Reason, _State, _Data) ->
    void.

code_change(_Vsn, _State) ->
    ok.


init(standard_io)  -> 
    {ok, {standard_io, 1}};
init({file, File}) -> 
    {ok, Fd} = file:open(File, write),
    {ok, {Fd, 1}};
init(Args) ->
    {error, {args, Args}}. 


%%%===================================================================
%%% Callback functions
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%%
%% Used when a non-OTP-standard message is sent to a manager.
%%
%%
%% @end
%%--------------------------------------------------------------------
handle_info(Info, _State) ->
    {ok,Info}.

%%--------------------------------------------------------------------
%% @doc
%%
%% Used when a manager is sent a request using gen_event:call/3/4.
%%
%%
%% @end
%%--------------------------------------------------------------------
handle_call(_Request,State)->
    Response = [],
    {ok,Response,State}.

%%--------------------------------------------------------------------
%% @doc
%%
%% Used when a manager is sent an event using gen_event:notify/2 or 
%% gen_event:sync_notify/2.
%%
%%
%% @end
%%--------------------------------------------------------------------
handle_event(Event, {Fd, Count}) -> 
    print(Fd, Count, Event, "Event"),
    {ok, {Fd, Count+1}}.

print(Fd, Count, Event, Tag) ->
    io:format(Fd, "Id:~w Time:~w Date:~w~n"++Tag++":~w~n",
              [Count,time(),date(),Event]).


%% This code is included in the compiled code only if 
%% 'rebar3 eunit' is being executed.
-ifdef(EUNIT).
-include_lib("eunit/include/eunit.hrl").
%%
%% Unit tests go here. 
%%
-endif.