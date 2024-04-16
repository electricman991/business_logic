-module(location_serv).
-behaviour(gen_server).

%% Only include the eunit testing library
%% in the compiled code if testing is 
%% being done.
-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-define(SERVER, ?MODULE).

%% API
-export([start/0,start/3,stop/0,get_location/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).


%%%===================================================================
%%% API
%%%===================================================================
%%% 
get_location(Data) ->
    gen_server:call(location_server, {location_for, Data}).
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

% handle_call({get_location, Data}, _From, {Riak_Pid, Event}) ->
%     gen_event:notify(logger_event, Event),
%     io:format("Location request received: ~p~n",[Data]),
%     {reply, "Location received", Event + 1};

% handle_call({get_location, Data}, _From, State) ->
%     {Riak_Pid, Event} = State,
%     gen_event:notify(logger_event, Event),
%     io:format("Location request received: ~p~n",[Data]),

%     {ok, Fetched} = db_api:get_location_for(<<"3d3ce96b-a635-46cd-8bcb-367a9c99c231">>,Riak_Pid),
%     Value = riakc_obj:get_value(Fetched),
%     Term = erlang:binary_to_term(Value),
%     {reply, Term, {Riak_Pid, Event + 1}};

handle_call({location_for, Data}, _From, State) ->
    {Riak_Pid, Event} = State,
    Key = maps:get(<<"package_id">>, Data),
    %gen_event:notify(logger_event, Event),
    %io:format("Location request received: ~p~n",[Key]),
    case {Key, is_binary(Key)} of
        {<<"">>, _} 
            -> {reply, #{<<"status">> => fail, error => empty_key}, State};

        %% Remove the error trigger case when the db_api is implemented
        % {<<"error_trigger">>, _} 
        %     -> {reply, db_api:get_location_for(Key,Value,State), State};
        {Key, true} 
            -> case re:run(Key, <<"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$">>) of
                
                {match, _} -> 
                    %io:format("Key: ~p~n",[Key]),
                    case db_api:get_package_location(Key,Riak_Pid) of
                        {error, _} -> 
                            {reply, #{<<"status">> => fail, error => <<"wrong_key: Could not retrieve data for provided Key">>}, State};
                        {ok, Fetched} ->
                            Value = riakc_obj:get_value(Fetched),
                            %io:format("Value: ~p~n",[Value]),
                            case is_binary(Value) of
                                true ->
                                    case db_api:get_location_for(Value, Riak_Pid) of 
                                        {error, _} -> 
                                            {reply, #{<<"status">> => fail, error => <<"wrong_key: Could not retrieve location">>}, State};
                                        {ok, NewFetched} -> 
                                            NewValue = riakc_obj:get_value(NewFetched),
                                            case NewValue of
                                                <<"Delivered">> -> 
                                                    Map = NewValue;
                                                _ -> 
                                                    Map = jsx:decode(NewValue)
                                                end,
                                            {reply, #{<<"status">> => success, <<"location">> => Map}, {Riak_Pid, Event + 1}}
                                            %     _ -> 
                                            %         Term = erlang:binary_to_term(NewValue),
                                            %         %Map = jsx:decode(Term, [return_maps]),
                                            %         %io:format("Map: ~p~n",[Map]),
                                            %         %Map = maps:from_list(List),
                                            %         %NewTerm = maps:put(<<"status">>, success, Map)
                                            %         {reply, #{<<"status">> => success, <<"location">> => Term}, {Riak_Pid, Event + 1}}
                                            % end
                                    end;
                                    
                                _ -> 
                                    %Term = erlang:binary_to_term(Value),
                                    %Map = jsx:decode(Value, [return_maps]),
                                    %Map = maps:from_list(List),
                                    %NewTerm = maps:put(<<"status">>, success, Map)
                                    {reply, #{<<"status">> => fail, <<"error">> => <<"Location_id not stored as binary string value ">>}, {Riak_Pid, Event + 1}}
                                end
                        end;
                    
                _ -> 
                    {reply, #{<<"status">> => fail, error => <<"wrong_key: Could not retrieve location">>}, State}
            end;
        {Key, _}
            -> 
                {reply, #{<<"status">> => fail, error => <<"wrong_key: Key is not correct type">>}, State}
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
handle_cast({update_location, Data}, State) ->
    io:format("Location update received: ~p~n",[Data]),
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
%% 
%% 
location_test_() ->
{setup,
     fun() -> %this setup fun is run once before the tests are run. If you want setup and teardown to run for each test, change {setup to {foreach
        meck:new(db_api),
        meck:expect(db_api, get_location_for, fun(Name_Key,Location,PID) -> 
            case Name_Key of 
                <<"error_trigger">> -> {error, some_error};
                _ -> #{lat=> 12443.2133, long=> 23321234}
            end 
        end)
        %meck:expect(db_api, put_package_for, fun(Name_key,Package,PID) -> worked end)
        
     end,
     fun(_) ->%This is the teardown fun. Notice it takes one, ignored in this example, parameter.
        meck:unload(db_api)
     end,
    [%This is the list of tests to be generated and run.
    ?_assertEqual({reply,#{lat=> 12443.2133, long=> 23321234},some_Db_PID},
        location_serv:handle_call({location_for,<<"3d3ce96b-a635-46cd-8bcb-367a9c99c231">>,[]}, some_from_pid, some_Db_PID)),
    ?_assertEqual({reply,{fail, wrong_key},some_Db_PID},
        location_serv:handle_call({location_for,<<"3726524345">>,[]}, some_from_pid, some_Db_PID)
        ),
    ?_assertEqual({reply,{fail,empty_key},some_Db_PID},
        location_serv:handle_call({location_for,<<"">>,[]}, some_from_pid, some_Db_PID)),
    ?_assertEqual({reply, {fail, wrong_key}, some_Db_PID},
        location_serv:handle_call({location_for,hsgd,[]}, some_from_pid, some_Db_PID)),

    ?_assertEqual({reply, {error, some_error}, some_Db_PID},
        location_serv:handle_call({location_for,<<"error_trigger">>,[]}, some_from_pid, some_Db_PID))
    ]}.
-endif.