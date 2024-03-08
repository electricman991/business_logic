%%%-------------------------------------------------------------------
%%% @author Lee Barney  <barney.cit@gmail.com>
%%% @copyright © 2022, Lee S. Barney
%%% @reference Licensed under the 
%%% <a href="http://creativecommons.org/licenses/by/4.0/">
%%% Creative Commons Attribution 4.0 International License</a>.
%%%
%%% @doc
%%% This is a template for supervisors that start up with no defined set of 
%%% OTP behaviors. Behaviors are then added and removed dynamically.
%%%
%%%
%%% @end

%%% Created : 24 October 2022 by Lee Barney <barney.cit@gmail.com>
%%%-------------------------------------------------------------------
-module(gen_server_sup).
-behaviour(supervisor).


%%%===================================================================
%%% Make sure to complete the documentation to match
%%% your supervisor's behavior and requirements.
%%%===================================================================

%%@private
-export([init/1]).
%%API functions
-export([start/0,start/1,start/3,add_child/4,remove_child/2]).

%%%===================================================================
%%% Public API functions
%%%===================================================================
%%--------------------------------------------------------------------
%% @doc
%%
%% Used if there is only one such supervisor created,
%% it is registered locally under the module name,
%% and there is no startup information, such as an
%% initial list of children to start.
%%
%%
%% @end
%%--------------------------------------------------------------------
start()->
    supervisor:start_link({local,?MODULE},?MODULE,[]).

%%--------------------------------------------------------------------
%% @doc
%%
%% Used if there is only one such supervisor created
%% and it is registered locally under the module name.
%%
%%
%% @end
%%--------------------------------------------------------------------
start(Start_info)->
    supervisor:start_link({local,?MODULE},?MODULE,Start_info).

%%--------------------------------------------------------------------
%% @doc
%%
%% Used if there can be many supervisors of this type
%% or if the supervisor is to be registered in any way 
%% but locally.
%%
%%
%% @end
%%--------------------------------------------------------------------
start(Supervisor_name,Registration_type,Start_info)->
    supervisor:start_link({Registration_type,Supervisor_name},?MODULE,Start_info).

%%--------------------------------------------------------------------
%% @doc
%%
%% Used to dynamically add a child to at run-time.
%%
%%
%% @end
%%--------------------------------------------------------------------
add_child(Supervisor_name,Child_name,Child_module,Child_type)->
        supervisor:start_child(Supervisor_name,generate_spec(Child_module,Child_name,Child_type)).


remove_child(Supervisor_name,Child_name)->
        supervisor:terminate_child(Supervisor_name,Child_name),
        supervisor:delete_child(Supervisor_name,Child_name).

%% Mandatory callback functions


%% Modify this function to do appropriate supervision initialization.
%%@private
init(Start_info) ->
    %% This function has a value that is a tuple
    %% consisting of ok, a description of how to 
    %% interact with its children, and a list of its children. It is missing
    %% the restart strategy, intensity and period you intend to use.
    %% this template also starts no children of its own. The information
    %% to do so would come from Start_info if any children are to be 
    %% started.
    %%
    %% The pattern for the value of this function is, 
    %% {ok,{{restart_strategy,intensity,period},children}}
    ChildSpecs = [
        {delivered_server, {delivered_serv, start, [local, delivered_server, []]}, permanent, 5000, worker, [delivered_serv]},
        {location_request_server, {location_serv, start, [local, location_server, []]}, permanent, 5000, worker, [location_serv]},
        {transfer_server, {transfer_serv, start, [local, transfer_server, []]}, permanent, 5000, worker, [transfer_serv]},
        {update_server, {update_serv, start, [local, update_server, []]}, permanent, 5000, worker, [update_serv]}
    ],
    {ok,{Start_info,ChildSpecs}}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

%% Modify this function to include an appropriate shutdown time, etc depending on which portions
%% of the child specification need to be set.
%%@private
generate_spec(Module,Name,Type)->
%%
%% A child Specification is a record with the following mappings.
%%
%% child_spec() = #{id => child_id(),       % mandatory. The name to be registered.
%%                  start => mfargs(),      % mandatory. The module's startup function.
%%                  restart => atom(),              % optional. Options are permanent (restart always), transient (restart only after abnormal termination), and temporary (never restart).
%%                  shutdown => integer()|atom(),   % optional. A number or the atom infinity representing the milliseconds allowed for a soft, normal shutdown before it is killed brutally.
%%                  type => atom(),                 % optional. Options are worker or supervisor.
%%                  modules => [module()]|atom()}   % optional. A list of modules to be considered for upgrading
%%                                                  % when the child's code is upgraded. The dynamic atom is used for when 
%%                                                  % such a list is unknown, for example when the child is a 
%%                                                  % gen_event manager with some unknown types of gen_event handler
%%                                                  % modules to be added later.
        #{id => Name,
          start => {Module,start,[local,Name,[]]},% This template forces local registration of the child and
                                                  % forces it to startup without parameters. 
          restart => transient,
          shutdown => 2000,
          type => Type,
          modules => [Module]}.