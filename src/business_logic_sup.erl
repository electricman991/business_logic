%%%-------------------------------------------------------------------
%% @doc business_logic top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(business_logic_sup).

-behaviour(supervisor).

-export([start_link/0]).

-export([init/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%% sup_flags() = #{strategy => strategy(),         % optional
%%                 intensity => non_neg_integer(), % optional
%%                 period => pos_integer()}        % optional
%% child_spec() = #{id => child_id(),       % mandatory
%%                  start => mfargs(),      % mandatory
%%                  restart => restart(),   % optional
%%                  shutdown => shutdown(), % optional
%%                  type => worker(),       % optional
%%                  modules => modules()}   % optional
init([]) ->
    SupFlags = #{strategy => one_for_all,
                 intensity => 0,
                 period => 1},

    GenServerSup = {gen_server_sup, {gen_server_sup, start, [{one_for_one, 2, 5 }]}, permanent, 5000, supervisor, [gen_server_sup]},

    LoggerSup = {clogger_sup, {clogger_sup, start, [{one_for_all, 1, 5}]}, permanent, 5000, supervisor, [clogger_sup]},
    ChildSpecs = [LoggerSup, GenServerSup],
    {ok, {SupFlags, ChildSpecs}}.

%% internal functions
