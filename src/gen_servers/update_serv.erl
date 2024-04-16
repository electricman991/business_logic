-module(update_serv).
-behaviour(gen_server).

%% Only include the eunit testing library
%% in the compiled code if testing is 
%% being done.
-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-define(SERVER, ?MODULE).

%% API
-export([start/0,start/3,stop/0,update_location/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%%%===================================================================
%%% API
%%%===================================================================

update_location(Data) ->
    gen_server:cast(update_server, {update_for, Data}),
    "ok".

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
	        {ok,Riak_Pid} ->
                {ok,{Riak_Pid,1}};
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
handle_call({update_for, Key, Value}, _From, Db_PID) ->
    case Key =:= <<"">> of
        true 
            -> {reply, {fail,empty_key}, Db_PID};
        _ 
            -> {reply, db_api:put_package_for(Key,Value,Db_PID), Db_PID}
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

handle_cast({update_for, Data}, State) ->
    {Riak_Pid, Event} = State,
    Cordinates = maps:get(<<"cordinates">>, Data, undefined),
    Key = maps:get(<<"location_id">>, Data, <<"">>),
    %io:format("Update request received: ~p~n",[Cordinates]),
    case {Key, is_binary(Key), maps:size(Cordinates) == 2} of
        {<<"">>, _,_} 
            -> %io:format("Empty key received~n",[]),
                %{noreply, #{<<"status">> => fail, error => empty_key}, State};
                {noreply, State};
        {Key, true, true} 
            -> JsonCordinates = jsx:encode(Cordinates),
                %io:format("Made it to database~p~n", [JsonCordinates]),
                
                case db_api:put_location_for(Key,JsonCordinates,Riak_Pid) of
                    ok -> 
                        %io:format("Data successfully saved~n",[]),
                        {noreply, {Riak_Pid, Event}};
                    {ok, _RiakObject} ->
                        %io:format("Data successfully saved~n",[]),
                        {noreply, {Riak_Pid, Event}};
                    {error, _Reason} ->
                        %io:format("Error saving data: ~p~n",[Reason]),
                        {noreply, {Riak_Pid, Event}}
                end;
        {Key, false, _}
            -> %io:format("Wrong key received~n",[]),
                {noreply, State};
        {Key, _, false}
            -> %io:format("Wrong number of values received~n",[]),
                {noreply, State}
    end.
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
update_test_() ->
{setup,
     fun() -> %this setup fun is run once befor the tests are run. If you want setup and teardown to run for each test, change {setup to {foreach
        meck:new(db_api),
        meck:expect(db_api, put_location_for, fun(Name_Key,Location,PID) -> 
            case Name_Key of 
                <<"error_trigger">> -> {error, some_error};
                _ -> worked
            end
        end)
        
     end,
     fun(_) ->%This is the teardown fun. Notice it takes one, ignored in this example, parameter.
        meck:unload(db_api)
     end,
    [
    ?_assertEqual({noreply,{fail, wrong_number_of_values},some_Db_PID},
        update_serv:handle_cast({update_for,<<"313243143132">>,[]}, some_Db_PID)),
    ?_assertEqual({noreply,worked,some_Db_PID},
        update_serv:handle_cast({update_for,<<"3726524345">>,[52785163523.432, 3422432134.432341]}, some_Db_PID)
        ),
    ?_assertEqual({noreply,{error,some_error},some_Db_PID},
        update_serv:handle_cast({update_for,<<"error_trigger">>,[34354213.321344, 45334.43214]}, some_Db_PID)),
    ?_assertEqual({noreply,{fail,empty_key},some_Db_PID},
        update_serv:handle_cast({update_for,<<"">>,[]}, some_Db_PID)),
    ?_assertEqual({noreply,{fail,wrong_number_of_values},some_Db_PID},
        update_serv:handle_cast({update_for,<<"313243143132">>,[<<"345335">>]}, some_Db_PID))
    ]}.
-endif.