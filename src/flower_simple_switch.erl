-module(flower_simple_switch).

-behaviour(gen_server).

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("flower_packet.hrl").
-include("flower_flow.hrl").

%% API
-export([start_link/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3]).

-define(SERVER, ?MODULE). 

-record(state, {}).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
init([]) ->
    flower_dispatcher:join({packet, in}),
    {ok, #state{}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast({{packet, in}, Sw, Msg}, State) ->
    case Flow = (catch flower_flow:flow_extract(0, Msg#ofp_packet_in.in_port, Msg#ofp_packet_in.data)) of
	#flow{} ->
	    %% choose destination...
	    Port = choose_destination(Flow),
	    Actions = case Port of
			  none -> [];
			  %%						 X when is_integer(X) ->
			  %%							 [#ofp_action_enqueue{port = X, queue_id = 0}];
			  X ->
			      [#ofp_action_output{port = X, max_len = 0}]
		      end,

	    if
		Port =:= flood ->
		    %% We don't know that MAC, or we don't set up flows.  Send along the
		    %% packet without setting up a flow.
		    flower_datapath:send_packet(Sw, Msg#ofp_packet_in.buffer_id, Msg#ofp_packet_in.data, Actions, Msg#ofp_packet_in.in_port);
		true ->
		    %% The output port is known, so add a new flow.
		    Match = flower_match:encode_ofp_matchflow([{nw_src_mask,32}, {nw_dst_mask,32}, tp_dst, tp_src, nw_proto, dl_type], Flow),
		    lager:debug("Match: ~p", [Match]),

		    flower_datapath:install_flow(Sw, Match, 0, 60, 0, Actions, Msg#ofp_packet_in.buffer_id, 0, Msg#ofp_packet_in.in_port, Msg#ofp_packet_in.data)
	    end;
	_ ->
	    lager:debug("no match: ~p", [Flow])
    end,
    {noreply, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
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
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

choose_destination(#flow{in_port = Port, dl_src = DlSrc, dl_dst = DlDst} = _Flow) ->
    OutPort = case flower_mac_learning:eth_addr_is_reserved(DlSrc) of
		  % Always use VLan = 0 to implement Shared VLAN Learning
		  false -> learn_mac(DlSrc, 0, Port),
			   find_out_port(DlDst, 0, Port);
		  true -> none
	      end,
    lager:debug("Verdict: ~p", [OutPort]),
    OutPort.

learn_mac(DlSrc, VLan, Port) ->		 
    R = case flower_mac_learning:may_learn(DlSrc, VLan) of
	    true -> flower_mac_learning:insert(DlSrc, VLan, Port);
	    false ->
		not_learned
	end,
    if
	R =:= new; R =:= updated ->
            lager:debug("~p: learned that ~s is on port ~w", [self(), flower_tools:format_mac(DlSrc), Port]),
	    ok;
	true ->
	    ok
    end.

find_out_port(DlDst, VLan, Port) ->
    OutPort = case flower_mac_learning:lookup(DlDst, VLan) of
		  none -> flood;
		  {ok, OutPort1} -> 
		      if
			  %% Don't send a packet back out its input port.
			  OutPort1 =:= Port -> none;
			  true -> OutPort1
		      end
	      end,
    OutPort.
