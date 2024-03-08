-module(delivered_serv).
-behaviour(gen_server).

%% Only include the eunit testing library
%% in the compiled code if testing is 
%% being done.
-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-define(SERVER, ?MODULE).

%% API
-export([start/0,start/3,stop/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server assuming there is only one server started for 
%% this module. The server is registered locally with the registered
%% name being the name of the module.
%%
%% @end
%%--------------------------------------------------------------------
-spec start() -> {ok, pid()} | ignore | {error, term()}.
start() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).
%%--------------------------------------------------------------------
%% @doc
%% Starts a server using this module and registers the server using
%% the name given.
%% Registration_type can be local or global.
%%
%% Args is a list containing any data to be passed to the gen_server's
%% init function.
%%
%% @end
%%--------------------------------------------------------------------
-spec start(atom(),atom(),atom()) -> {ok, pid()} | ignore | {error, term()}.
start(Registration_type,Name,Args) ->
    gen_server:start_link({Registration_type, Name}, ?MODULE, Args, []).


%%--------------------------------------------------------------------
%% @doc
%% Stops the server gracefully
%%
%% @end
%%--------------------------------------------------------------------
-spec stop() -> {ok}|{error, term()}.
stop() -> gen_server:call(?MODULE, stop).

%% Any other API functions go here.

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @end
%%--------------------------------------------------------------------
-spec init(term()) -> {ok, term()}|{ok, term(), number()}|ignore |{stop, term()}.
init([]) ->
        {ok,replace_up}.
%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @end
%%--------------------------------------------------------------------
-spec handle_call(Request::term(), From::pid(), State::term()) ->
                                  {reply, term(), term()} |
                                  {reply, term(), term(), integer()} |
                                  {noreply, term()} |
                                  {noreply, term(), integer()} |
                                  {stop, term(), term(), integer()} | 
                                  {stop, term(), term()}.
handle_call({delivered_for, Key, Value}, _From, Db_PID) ->
    case {Key, is_binary(Key), Value =/= []} of
        {<<"">>, _,_} 
            -> {reply, {fail,empty_key}, Db_PID};

        %% Remove the error trigger case when the db_api is implemented
        {<<"error_trigger">>,_,_}
            -> {reply, db_api:put_location_for(Key,Value,Db_PID), Db_PID};
        {Key, true, true} 
            -> case re:run(Key, <<"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$">>) of
                {match, _} -> {reply, db_api:put_location_for(Key,Value,Db_PID), Db_PID};
                _ -> {reply, {fail, wrong_key}, Db_PID}
            end;
        {Key, false, _}
            -> {reply, {fail, wrong_key}, Db_PID};
        {Key, true, false}
            -> {reply, {fail, empty_value}, Db_PID}
    end;
handle_call(stop, _From, _State) ->
        {stop,normal,
                replace_stopped,
          down}. %% setting the server's internal state to down

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @end
%%--------------------------------------------------------------------
-spec handle_cast(Msg::term(), State::term()) -> {noreply, term()} |
                                  {noreply, term(), integer()} |
                                  {stop, term(), term()}.
handle_cast(_Msg, State) ->
    {noreply, State}.
    
%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @end
-spec handle_info(Info::term(), State::term()) -> {noreply, term()} |
                                   {noreply, term(), integer()} |
                                   {stop, term(), term()}.
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @end
%%--------------------------------------------------------------------
-spec terminate(Reason::term(), term()) -> term().
terminate(_Reason, _State) ->
    ok.
    
%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @end
%%--------------------------------------------------------------------
-spec code_change(term(), term(), term()) -> {ok, term()}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
    
%%%===================================================================
%%% Internal functions
%%%===================================================================



-ifdef(EUNIT).
%%
%% Unit tests go here. 
%%
delivered_test_() ->
{setup,
     fun() -> %this setup fun is run once before the tests are run. If you want setup and teardown to run for each test, change {setup to {foreach
        meck:new(db_api),
        meck:expect(db_api, put_location_for, fun(Name_Key,Location,PID) -> 
            case Name_Key of 
                <<"error_trigger">> -> {error, some_error};
                _ -> worked
            end  
        end)
        %meck:expect(db_api, put_package_for, fun(Name_key,Package,PID) -> worked end)
        
     end,
     fun(_) ->%This is the teardown fun. Notice it takes one, ignored in this example, parameter.
        meck:unload(db_api)
     end,
    [
    ?_assertEqual({reply,worked,some_Db_PID},
        delivered_serv:handle_call({delivered_for,<<"3d3ce96b-a635-46cd-8bcb-367a9c99c231">>,["delivered"]}, some_from_pid, some_Db_PID)),
    ?_assertEqual({reply,{fail, empty_value},some_Db_PID},
        delivered_serv:handle_call({delivered_for,<<"3726524345">>,[]}, some_from_pid, some_Db_PID)
        ),
    ?_assertEqual({reply,{fail,empty_key},some_Db_PID},
        delivered_serv:handle_call({delivered_for,<<"">>,[]}, some_from_pid, some_Db_PID)),
    ?_assertEqual({reply,{fail,wrong_key},some_Db_PID},
        delivered_serv:handle_call({delivered_for,rswvgxs,[]}, some_from_pid, some_Db_PID)),
    ?_assertEqual({reply,{error,some_error},some_Db_PID},
        delivered_serv:handle_call({delivered_for,<<"error_trigger">>,["delivered"]}, some_from_pid, some_Db_PID))
    ]}.
-endif.