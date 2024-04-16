-module(transfer_serv).
-behaviour(gen_server).

%% Only include the eunit testing library
%% in the compiled code if testing is 
%% being done.
-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-define(SERVER, ?MODULE).

%% API
-export([start/0,start/3,stop/0, transfer_package/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%%%===================================================================
%%% API
%%%===================================================================

transfer_package(Data) ->
    Location_id = maps:get(<<"location_id">>, Data, undefined),
    %io:format("Location_id~p~n", [Location_id]),
    Package_id = maps:get(<<"package_id">>, Data, undefined),
    gen_server:call(transfer_server, {transfer_for, Package_id, Location_id}).
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
        case riakc_pb_socket:start_link("rdb.parallelcompute.net", 8087) of 
	     {ok,Riak_Pid} -> {ok,{Riak_Pid,1}};
	     _ -> {stop,link_failure}
	end.
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
handle_call({transfer_for, Key, Value}, _From, State) ->
    {Riak_Pid, Event} = State,
    %io:format("Transfer Key: ~p~n Location Key: ~p~n", [Key, Value]),
    case {Key, is_binary(Key), Value =/= [] } of
        {<<"">>, _, _} 
            -> {reply, #{<<"status">> => fail, message => empty_key}, State};

        %% Remove this case when going to production
        % {<<"error_trigger">>, _, _}
        %     -> {reply, dp_api:put_package_for(Key,Value,State), State};
        {Key, true, true} 
            -> case re:run(Key, "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$") of
                {match, _} -> 
                    case db_api:put_package_for(Key,Value,Riak_Pid) of
                        ok ->
                            case db_api:get_location_for(Value, Riak_Pid) of
                                ok -> 
                                    {reply, #{<<"status">> => success, message => <<"Data successfully saved">>}, {Riak_Pid, Event + 1}};
                                {ok, _RiakObject} ->
                                    {reply, #{<<"status">> => success, message => <<"Data successfully saved">>}, {Riak_Pid, Event + 1}};
                                {error, _Error} ->
                                    Cor = jsx:encode(#{<<"lat">> => 0.00, <<"long">> => 0.00}),
                                    db_api:put_location_for(Value, Cor, Riak_Pid),
                                    {reply, #{<<"status">> => success, message => <<"Data successfully saved">>}, {Riak_Pid, Event + 1}}
                            end;
                        {ok, _RiakObject} -> 
                            %gen_event:notify(logger_event, {Key, Value}),
                            {reply,#{<<"status">> => success, message => <<"Data successfully saved">>},{Riak_Pid, Event + 1}};
                        {error, Error} ->
                            %gen_event:notify(logger_event, {Key, Error}),
                            {reply, #{<<"status">> => fail, error => Error}, State};
                        _ ->
                            {reply, #{<<"status">> => fail, error => unknown_error}, State}
                    end;
                    
                _ -> {reply, #{<<"status">> => fail, error => <<"wrong_key: could not transfer package">>}, State}
            end;
        {Key, false, _}
            -> {reply, #{<<"status">> => fail, error => <<"wrong_key: Key is not correct type">>}, State};
        {Key, true, false}
            -> {reply, #{<<"status">> => fail, error => <<"empty_value: No Value provided, could not transfer package">>}, State}
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
transfer_serv_test_() ->
    {setup,
     fun() -> %this setup fun is run once befor the tests are run. If you want setup and teardown to run for each test, change {setup to {foreach
        meck:new(db_api),
        meck:expect(db_api, put_location_for, fun(Name_Key,Location,PID) -> 
            case Name_Key of 
                error_trigger -> {error, some_error};
                _ -> worked
            end
        end),
        meck:expect(db_api, put_package_for, fun(Name_Key,Package,PID) -> 
            case Name_Key of 
                error_trigger -> {error, some_error};
                _ -> worked 
            end
        end)
        
     end,
     fun(_) ->%This is the teardown fun. Notice it takes one, ignored in this example, parameter.
        meck:unload(db_api)
     end,
    [
    ?_assertEqual({reply,worked,some_Db_PID},
        transfer_serv:handle_call({transfer_for,<<"3d3ce96b-a635-46cd-8bcb-367a9c99c231">>,[<<"3d3ce96b-a635-46cd-8bcb-367a9c99c231">>]}, some_from_pid, some_Db_PID)),
    ?_assertEqual({reply,{fail, wrong_key},some_Db_PID},
        transfer_serv:handle_call({transfer_for,<<"3726524345">>,[<<"52785163523">>]}, some_from_pid, some_Db_PID)
        ),
    ?_assertEqual({reply,{fail,empty_key},some_Db_PID},
        transfer_serv:handle_call({transfer_for,<<"">>,[]}, some_from_pid, some_Db_PID)),
    ?_assertEqual({reply,{fail,empty_value},some_Db_PID},
        transfer_serv:handle_call({transfer_for,<<"64332785326">>,[]}, some_from_pid, some_Db_PID)),
    ?_assertEqual({reply,{fail,wrong_key},some_Db_PID},
        transfer_serv:handle_call({transfer_for,sgfd,[]}, some_from_pid, some_Db_PID))
    ]}.
-endif.

%% Put in real data (ok)
%% Put in empty strings (fail)
%% Put in empty key (fail)
%% Put in invalid key (fail)