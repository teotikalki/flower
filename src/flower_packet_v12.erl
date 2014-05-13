-module(flower_packet_v12).

%% API
-export([encode/1, encode_msg/1, decode/1]).
%% constant mappers
-export([ofpt/1, ofp_packet_in_reason/1, ofp_config_flags/1,
	 ofp_flow_mod_command/1, eth_type/1]).
%% part encoders
-export([encode_actions/1,
	 encode_action/1]).

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("flower_packet.hrl").

%% --------------------------------------------------------------------
-type int8() :: 0..16#ff.
-type int16() :: 0..16#ffff.
-type int32() :: 0..16#ffffffff.

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------

decode(Msg) ->
    decode(Msg, []).

decode(<<Version:8/integer, Type:8/integer, Length:16/integer, Xid:32/integer,
	 _/binary>> = Data, Acc)
  when size(Data) >= Length ->
    MsgLen = Length - 8,
    <<_Hdr:8/bytes, Msg:MsgLen/bytes, Rest/binary>> = Data,
    MType = ofpt(Type),
    M = decode_msg(MType, Msg),
    lager:debug("decode got: ~p", [M]),
    decode(Rest, [#ovs_msg{version = Version, type = MType, xid = Xid, msg = M}|Acc]);

decode(Rest, Acc) ->
    {lists:reverse(Acc), Rest}.

encode(#ovs_msg{version = Version, type = Type, xid = Xid, msg = Msg}) ->
    Mtype = ofpt(Type),
    Data = encode_msg(Msg),
    Length = size(Data) + 8,
    lager:debug("~p ~p ~p ~p ~p", [Version, Mtype, Length, Xid, Msg]),
    R = <<Version:8, Mtype:8, Length:16, Xid:32, Data/binary>>,
    lager:debug("Send: ~p", [R]),
    R;

encode(Msg) when is_list(Msg) ->
    encode(Msg, []).

encode([], Acc) ->
    list_to_binary(lists:reverse(Acc));
encode([Msg|Rest], Acc) ->
    encode(Rest, [encode(Msg)|Acc]).

%%%===================================================================
%%% constant, flags and enum translators
%%%===================================================================

%% Match Types
-define(OFPMT_STANDARD, 0).
-define(OFPMT_OXM, 1).

-define(OFPXMC_NXM_0,		16#0000).		%% Backward compatibility with NXM
-define(OFPXMC_NXM_1,		16#0001).		%% Backward compatibility with NXM
-define(OFPXMC_OPENFLOW_BASIC,	16#8000).		%% Basic class for OpenFlow
-define(OFPXMC_EXPERIMENTER,	16#ffff).		%% Experimenter class

-define(OFPXMT_OFB_IN_PORT,		0).		%% Switch input port.
-define(OFPXMT_OFB_IN_PHY_PORT,		1).		%% Switch physical input port.
-define(OFPXMT_OFB_METADATA,		2).		%% Metadata passed between tables.
-define(OFPXMT_OFB_ETH_DST,		3).		%% Ethernet destination address.
-define(OFPXMT_OFB_ETH_SRC,		4).		%% Ethernet source address.
-define(OFPXMT_OFB_ETH_TYPE,		5).		%% Ethernet frame type.
-define(OFPXMT_OFB_VLAN_VID,		6).		%% VLAN id.
-define(OFPXMT_OFB_VLAN_PCP,		7).		%% VLAN priority.
-define(OFPXMT_OFB_IP_DSCP,		8).		%% IP DSCP (6 bits in ToS field).
-define(OFPXMT_OFB_IP_ECN,		9).		%% IP ECN (2 bits in ToS field).
-define(OFPXMT_OFB_IP_PROTO,		10).		%% IP protocol.
-define(OFPXMT_OFB_IPV4_SRC,		11).		%% IPv4 source address.
-define(OFPXMT_OFB_IPV4_DST,		12).		%% IPv4 destination address.
-define(OFPXMT_OFB_TCP_SRC,		13).		%% TCP source port.
-define(OFPXMT_OFB_TCP_DST,		14).		%% TCP destination port.
-define(OFPXMT_OFB_UDP_SRC,		15).		%% UDP source port.
-define(OFPXMT_OFB_UDP_DST,		16).		%% UDP destination port.
-define(OFPXMT_OFB_SCTP_SRC,		17).		%% SCTP source port.
-define(OFPXMT_OFB_SCTP_DST,		18).		%% SCTP destination port.
-define(OFPXMT_OFB_ICMPV4_TYPE,		19).		%% ICMP type.
-define(OFPXMT_OFB_ICMPV4_CODE,		20).		%% ICMP code.
-define(OFPXMT_OFB_ARP_OP,		21).		%% ARP opcode.
-define(OFPXMT_OFB_ARP_SPA,		22).		%% ARP source IPv4 address.
-define(OFPXMT_OFB_ARP_TPA,		23).		%% ARP target IPv4 address.
-define(OFPXMT_OFB_ARP_SHA,		24).		%% ARP source hardware address.
-define(OFPXMT_OFB_ARP_THA,		25).		%% ARP target hardware address.
-define(OFPXMT_OFB_IPV6_SRC,		26).		%% IPv6 source address.
-define(OFPXMT_OFB_IPV6_DST,		27).		%% IPv6 destination address.
-define(OFPXMT_OFB_IPV6_FLABEL,		28).		%% IPv6 Flow Label
-define(OFPXMT_OFB_ICMPV6_TYPE,		29).		%% ICMPv6 type.
-define(OFPXMT_OFB_ICMPV6_CODE,		30).		%% ICMPv6 code.
-define(OFPXMT_OFB_IPV6_ND_TARGET,	31).		%% Target address for ND.
-define(OFPXMT_OFB_IPV6_ND_SLL,		32).		%% Source link-layer for ND.
-define(OFPXMT_OFB_IPV6_ND_TLL,		33).		%% Target link-layer for ND.
-define(OFPXMT_OFB_MPLS_LABEL,		34).		%% MPLS label.
-define(OFPXMT_OFB_MPLS_TC,		35).		%% MPLS TC.

%% ROFL OF1.0 backwards compatibility
-define(OFPXMT_OFX_NW_SRC,		 0).		%% network layer source address
-define(OFPXMT_OFX_NW_DST,		 1).		%% network layer destination address
-define(OFPXMT_OFX_NW_PROTO,		 2).		%% network layer proto/arp code...
-define(OFPXMT_OFX_TP_SRC,		 3).		%% transport protocol source port
-define(OFPXMT_OFX_TP_DST,		 4).		%% transport protocol destination port

%% ROFL PPP/PPPoE related extensions
-define(OFPXMT_OFX_PPPOE_CODE,		21).		%% PPPoE code
-define(OFPXMT_OFX_PPPOE_TYPE,		22).		%% PPPoE type
-define(OFPXMT_OFX_PPPOE_SID,		23).		%% PPPoE session id
-define(OFPXMT_OFX_PPP_PROT,		24).		%% PPP protocol

%% ROFL GTP related extensions
-define(OFPXMT_OFX_GTP_MSG_TYPE,	25).		%% GTP message type
-define(OFPXMT_OFX_GTP_TEID,		26).		%% GTP tunnel endpoint identifier

%% ROFL CAPWAP related extensions
-define(OFPXMT_OFX_CAPWAP_WBID,         27).		%% CAPWAP Wireless Binding Id
-define(OFPXMT_OFX_CAPWAP_RID,          28).		%% CAPWAP Radio Id
-define(OFPXMT_OFX_CAPWAP_FLAGS,        29).		%% CAPWAP Flags

%% ROFL IEEE 802.11 related extensions
-define(OFPXMT_OFX_IEEE80211_FC,        30).		%% IEEE 802.11 Frame Control field
-define(OFPXMT_OFX_IEEE80211_TYPE,      31).		%% IEEE 802.11 Type field
-define(OFPXMT_OFX_IEEE80211_SUBTYPE,   32).		%% IEEE 802.11 SubType field
-define(OFPXMT_OFX_IEEE80211_DIRECTION, 33).		%% IEEE 802.11 FromDS / ToDS fields
-define(OFPXMT_OFX_IEEE80211_ADDRESS_1, 34).		%% IEEE 802.11 Address 1 field
-define(OFPXMT_OFX_IEEE80211_ADDRESS_2, 35).		%% IEEE 802.11 Address 2 field
-define(OFPXMT_OFX_IEEE80211_ADDRESS_3, 36).		%% IEEE 802.11 Address 3 field

%% Action
-define(OFP12AT_OUTPUT,		 0).		%% Output to switch port.
-define(OFP12AT_COPY_TTL_OUT,	11).		%% Copy TTL "outwards" -- from next-to-outermost to outermost
-define(OFP12AT_COPY_TTL_IN,	12).		%% Copy TTL "inwards" -- from outermost to next-to-outermost
-define(OFP12AT_SET_MPLS_TTL,	15).		%% MPLS TTL
-define(OFP12AT_DEC_MPLS_TTL,	16).		%% Decrement MPLS TTL
-define(OFP12AT_PUSH_VLAN,	17).		%% Push a new VLAN tag
-define(OFP12AT_POP_VLAN,	18).		%% Pop the outer VLAN tag
-define(OFP12AT_PUSH_MPLS,	19).		%% Push a new MPLS tag
-define(OFP12AT_POP_MPLS,	20).		%% Pop the outer MPLS tag
-define(OFP12AT_SET_QUEUE,	21).		%% Set queue id when outputting to a port
-define(OFP12AT_GROUP,		22).		%% Apply group.
-define(OFP12AT_SET_NW_TTL,	23).		%% IP TTL.
-define(OFP12AT_DEC_NW_TTL,	24).		%% Decrement IP TTL.
-define(OFP12AT_SET_FIELD,	25).		%% Set a header field using OXM TLV format.
-define(OFP12AT_EXPERIMENTER,	16#ffff).

%% ROFL Experimental Actions
-define(OFXAT_PUSH_PPPOE,		1).
-define(OFXAT_POP_PPPOE,		2).

%% Travelping Experimental Actions
-define(OFXAT_TP_PUSH_CAPWAP,		0).
-define(OFXAT_TP_POP_CAPWAP,		1).
-define(OFXAT_TP_PUSH_IEEE80211,	2).
-define(OFXAT_TP_POP_IEEE80211,		3).

-define(ROFL_EXPERIMENTER_ID,           16#555501dd).
-define(TRAVELPING_EXPERIMENTER_ID,     16#00001F30).

ofp_xmt_type() ->
    [in_port, in_phy_port, metadata, eth_dst, eth_src, eth_type, vlan_vid,
     vlan_pcp, ip_dscp, ip_ecn, ip_proto, ipv4_src, ipv4_dst, tcp_src, tcp_dst,
     udp_src, udp_dst, sctp_src, sctp_dst, icmpv4_type, icmpv4_code, arp_op,
     arp_spa, arp_tpa, arp_sha, arp_tha, ipv6_src, ipv6_dst, ipv6_flabel,
     icmpv6_type, icmpv6_code, ipv6_nd_target, ipv6_nd_sll, ipv6_nd_tll,
     mpls_label, mpls_tc].

experimenter(?ROFL_EXPERIMENTER_ID)       -> rofl;
experimenter(?TRAVELPING_EXPERIMENTER_ID) -> travelping;
experimenter(rofl)                        -> ?ROFL_EXPERIMENTER_ID;
experimenter(travelping)                  -> ?TRAVELPING_EXPERIMENTER_ID;
experimenter(X) when is_integer(X) -> X.

eth_type(?ETH_TYPE_IP)    -> ip;
eth_type(?ETH_TYPE_ARP)   -> arp;
eth_type(?ETH_TYPE_RARP)  -> rarp;
eth_type(?ETH_TYPE_MOPRC) -> moprc;
eth_type(?ETH_TYPE_VLAN)  -> vlan;
eth_type(?ETH_TYPE_IPV6)  -> ipv6;
eth_type(?ETH_TYPE_LACP)  -> lacp;
eth_type(?ETH_TYPE_LOOP)  -> loop;
eth_type(X) when is_integer(X) -> X;

eth_type(none)  -> ?ETH_TYPE_NONE;
eth_type(ip)    -> ?ETH_TYPE_IP;
eth_type(arp)   -> ?ETH_TYPE_ARP;
eth_type(rarp)  -> ?ETH_TYPE_RARP;
eth_type(moprc) -> ?ETH_TYPE_MOPRC;
eth_type(vlan)  -> ?ETH_TYPE_VLAN;
eth_type(ipv6)  -> ?ETH_TYPE_IPV6;
eth_type(lacp)  -> ?ETH_TYPE_LACP;
eth_type(loop)  -> ?ETH_TYPE_LOOP;
eth_type(undefined) -> 0.

ofpt(0)		-> hello;
ofpt(1)		-> error;
ofpt(2)		-> echo_request;
ofpt(3)		-> echo_reply;
ofpt(4)		-> experimenter;
ofpt(5)		-> features_request;
ofpt(6)		-> features_reply;
ofpt(7)		-> get_config_request;
ofpt(8)		-> get_config_reply;
ofpt(9)		-> set_config;
ofpt(10)	-> packet_in;
ofpt(11)	-> flow_removed;
ofpt(12)	-> port_status;
ofpt(13)	-> packet_out;
ofpt(14)	-> flow_mod;
ofpt(15)	-> group_mod;
ofpt(16)	-> port_mod;
ofpt(17)	-> table_mod;
ofpt(18)	-> stats_request;
ofpt(19)	-> stats_reply;
ofpt(20)	-> barrier_request;
ofpt(21)	-> barrier_reply;
ofpt(22)	-> queue_get_config_request;
ofpt(23)	-> queue_get_config_reply;
ofpt(24)	-> role_request;
ofpt(25)	-> role_reply;

ofpt(hello)			-> 0;
ofpt(error)			-> 1;
ofpt(echo_request)		-> 2;
ofpt(echo_reply)		-> 3;
ofpt(vendor)			-> 4;
ofpt(experimenter)		-> 4;
ofpt(features_request)		-> 5;
ofpt(features_reply)		-> 6;
ofpt(get_config_request)	-> 7;
ofpt(get_config_reply)		-> 8;
ofpt(set_config)		-> 9;
ofpt(packet_in)			-> 10;
ofpt(flow_removed)		-> 11;
ofpt(port_status)		-> 12;
ofpt(packet_out)		-> 13;
ofpt(flow_mod)			-> 14;
ofpt(group_mod)			-> 15;
ofpt(port_mod)			-> 16;
ofpt(table_mod)			-> 17;
ofpt(stats_request)		-> 18;
ofpt(stats_reply)		-> 19;
ofpt(barrier_request)		-> 20;
ofpt(barrier_reply)		-> 21;
ofpt(queue_get_config_request)	-> 22;
ofpt(queue_get_config_reply)	-> 23;
ofpt(role_request)		-> 24;
ofpt(role_reply)		-> 25;

ofpt(_)		-> error.

-spec ofp_error_type(non_neg_integer()) -> ofp_error_type() | non_neg_integer();
		    (ofp_error_type()) -> non_neg_integer().
ofp_error_type(hello_failed)		-> 0;			%% Hello protocol failed.
ofp_error_type(bad_request)		-> 1;			%% Request was not understood.
ofp_error_type(bad_action)		-> 2;			%% Error in action description.
ofp_error_type(bad_instruction)		-> 3;			%% Error in instruction list.
ofp_error_type(bad_match)		-> 4;			%% Error in match.
ofp_error_type(flow_mod_failed)		-> 5;			%% Problem modifying flow entry.
ofp_error_type(group_mod_failed)	-> 6;			%% Problem modifying group entry.
ofp_error_type(port_mod_failed)		-> 7;			%% Port mod request failed.
ofp_error_type(table_mod_failed)	-> 8;			%% Table mod request failed.
ofp_error_type(queue_op_failed)		-> 9;			%% Queue operation failed.
ofp_error_type(switch_config_failed)	-> 10;			%% Switch config request failed.
ofp_error_type(role_request_failed)	-> 11;			%% Controller Role request failed.

ofp_error_type(0)	-> hello_failed;
ofp_error_type(1)	-> bad_request;
ofp_error_type(2)	-> bad_action;
ofp_error_type(3)	-> bad_instruction;
ofp_error_type(4)	-> bad_match;
ofp_error_type(5)	-> flow_mod_failed;
ofp_error_type(6)	-> group_mod_failed;
ofp_error_type(7)	-> port_mod_failed;
ofp_error_type(8)	-> table_mod_failed;
ofp_error_type(9)	-> queue_op_failed;
ofp_error_type(10)	-> switch_config_failed;
ofp_error_type(11)	-> role_request_failed;

ofp_error_type(X) when is_integer(X) -> X.

-spec ofp_error_code_type(ofp_error_type(), non_neg_integer()) -> atom() | 'error';
			 (ofp_error_type(), atom()) -> non_neg_integer() | 'error'.
ofp_error_code_type(hello_failed, 0) -> incompatible;
ofp_error_code_type(hello_failed, 1) -> eperm;

ofp_error_code_type(bad_request, 0) -> bad_version;		%% ofp_header.version not supported.
ofp_error_code_type(bad_request, 1) -> bad_type;		%% ofp_header.type not supported.
ofp_error_code_type(bad_request, 2) -> bad_stat;		%% ofp_stats_request.type not supported.
ofp_error_code_type(bad_request, 3) -> bad_experimenter;	%% Experimenter id not supported
								%% (in ofp_experimenter_header or
								%% ofp_stats_request or ofp_stats_reply).
ofp_error_code_type(bad_request, 4) -> bad_subtype;		%% Experimenter type not supported.
ofp_error_code_type(bad_request, 5) -> eperm;			%% Permissions error.
ofp_error_code_type(bad_request, 6) -> bad_len;			%% Wrong request length for type.
ofp_error_code_type(bad_request, 7) -> buffer_empty;		%% Specified buffer has already been used.
ofp_error_code_type(bad_request, 8) -> buffer_unknown;		%% Specified buffer does not exist.
ofp_error_code_type(bad_request, 9) -> bad_table_id;		%% Specified table-id invalid or does not
								%% exist.
ofp_error_code_type(bad_request, 10) -> slave;			%% Denied because controller is slave.
ofp_error_code_type(bad_request, 11) -> bad_port;		%% Invalid port.
ofp_error_code_type(bad_request, 12) -> bad_packet;		%% Invalid packet in packet-out.


ofp_error_code_type(bad_action, 0) -> bad_type;			%% Unknown action type.
ofp_error_code_type(bad_action, 1) -> bad_len;			%% Length problem in actions.
ofp_error_code_type(bad_action, 2) -> bad_experimenter;		%% Unknown experimenter id specified.
ofp_error_code_type(bad_action, 3) -> bad_experimenter_type;	%% Unknown action for experimenter id.
ofp_error_code_type(bad_action, 4) -> bad_out_port;		%% Problem validating output port.
ofp_error_code_type(bad_action, 5) -> bad_argument;		%% Bad action argument.
ofp_error_code_type(bad_action, 6) -> eperm;			%% Permissions error.
ofp_error_code_type(bad_action, 7) -> too_many;			%% Can’t handle this many actions.
ofp_error_code_type(bad_action, 8) -> bad_queue;		%% Problem validating output queue.
ofp_error_code_type(bad_action, 9) -> bad_out_group;		%% Invalid group id in forward action.
ofp_error_code_type(bad_action, 10) -> match_inconsistent;	%% Action can’t apply for this match,
								%% or Set-Field missing prerequisite.
ofp_error_code_type(bad_action, 11) -> unsupported_order;	%% Action order is unsupported for the
								%% action list in an Apply-Actions instruction
ofp_error_code_type(bad_action, 12) -> bad_bad_tag;		%% Actions uses an unsupported
								%% tag/encap.
ofp_error_code_type(bad_action, 13) -> bad_set_type;		%% Unsupported type in SET_FIELD action.
ofp_error_code_type(bad_action, 14) -> bad_set_len;		%% Length problem in SET_FIELD action.
ofp_error_code_type(bad_action, 15) -> bad_set_argument;	%% Bad argument in SET_FIELD action.

ofp_error_code_type(bad_instruction_code, 0)	-> unknown_inst;				%% Unknown instruction.
ofp_error_code_type(bad_instruction_code, 1)	-> unsup_inst;					%% Switch or table does not support the instruction.
ofp_error_code_type(bad_instruction_code, 2)	-> bad_table_id;				%% Invalid Table-ID specified.
ofp_error_code_type(bad_instruction_code, 3)	-> unsup_metadata;				%% Metadata value unsupported by datapath.
ofp_error_code_type(bad_instruction_code, 4)	-> unsup_metadata_mask;				%% Metadata mask value unsupported by datapath.
ofp_error_code_type(bad_instruction_code, 5)	-> bad_experimenter;				%% Unknown experimenter id specified.
ofp_error_code_type(bad_instruction_code, 6)	-> bad_exp_type;				%% Unknown instruction for experimenter id.
ofp_error_code_type(bad_instruction_code, 7)	-> bad_len;					%% Length problem in instructions.
ofp_error_code_type(bad_instruction_code, 8)	-> eperm;					%% Permissions error.


ofp_error_code_type(bad_match_code, 0)		-> bad_type;					%% Unsupported match type specified by the
												%% match
ofp_error_code_type(bad_match_code, 1)		-> bad_len;					%% Length problem in match.
ofp_error_code_type(bad_match_code, 2)		-> bad_tag;					%% Match uses an unsupported tag/encap.
ofp_error_code_type(bad_match_code, 3)		-> bad_dl_addr_mask;				%% Unsupported datalink addr mask - switch does
												%% not support arbitrary datalink address
												%% mask.
ofp_error_code_type(bad_match_code, 4)		-> bad_nw_addr_mask;				%% Unsupported network addr mask - switch does
												%% not support arbitrary network address
												%% mask.
ofp_error_code_type(bad_match_code, 5)		-> bad_wildcards;				%% Unsupported wildcard specified in the
												%% match.
ofp_error_code_type(bad_match_code, 6)		-> bad_field;					%% Unsupported field in the match.
ofp_error_code_type(bad_match_code, 7)		-> bad_value;					%% Unsupported value in a match field.
ofp_error_code_type(bad_match_code, 8)		-> bad_mask;					%% Unsupported mask specified in the match,
												%% field is not dl-address or nw-address.
ofp_error_code_type(bad_match_code, 9)		-> bad_prereq;					%% A prerequisite was not met.
ofp_error_code_type(bad_match_code, 10)		-> dup_field;					%% A field type was duplicated.
ofp_error_code_type(bad_match_code, 11)		-> eperm;					%% Permissions error.

ofp_error_code_type(flow_mod_failed, 0)		-> unknown;					%% Unspecified error.
ofp_error_code_type(flow_mod_failed, 1)		-> tables_full;					%% Flow not added because table was full.
ofp_error_code_type(flow_mod_failed, 2)		-> bad_table_id;				%% Table does not exist
ofp_error_code_type(flow_mod_failed, 3)		-> overlap;					%% Attempted to add overlapping flow with
												%% CHECK_OVERLAP flag set.
ofp_error_code_type(flow_mod_failed, 4)		-> eperm;					%% Permissions error.
ofp_error_code_type(flow_mod_failed, 5)		-> bad_timeout;					%% Flow not added because of unsupported
												%% idle/hard timeout.
ofp_error_code_type(flow_mod_failed, 6)		-> bad_command;					%% Unsupported or unknown command.
ofp_error_code_type(flow_mod_failed, 7)		-> bad_flags;					%% Unsupported or unknown flags.

ofp_error_code_type(group_mod_failed, 0)	-> group_exists;				%% Group not added because a group ADD
												%% attempted to replace an
												%% already-present group.
ofp_error_code_type(group_mod_failed, 1)	-> invalid_group;				%% Group not added because Group specified
												%% is invalid.
ofp_error_code_type(group_mod_failed, 2)	-> weight_unsupported;				%% Switch does not support unequal load
												%% sharing with select groups.
ofp_error_code_type(group_mod_failed, 3)	-> out_of_groups;				%% The group table is full.
ofp_error_code_type(group_mod_failed, 4)	-> out_of_buckets;				%% The maximum number of action buckets
												%% for a group has been exceeded.
ofp_error_code_type(group_mod_failed, 5)	-> chaining_unsupported;			%% Switch does not support groups that
												%% forward to groups.
ofp_error_code_type(group_mod_failed, 6)	-> watch_unsupported;				%% This group cannot watch the
												%% watch_port or watch_group specified.
ofp_error_code_type(group_mod_failed, 7)	-> loop;					%% Group entry would cause a loop.
ofp_error_code_type(group_mod_failed, 8)	-> unknown_group;				%% Group not modified because a group
												%% MODIFY attempted to modify a
												%% non-existent group.
ofp_error_code_type(group_mod_failed, 9)	-> chained_group;				%% Group not deleted because another
												%% group is forwarding to it.
ofp_error_code_type(group_mod_failed, 10)	-> bad_type;					%% Unsupported or unknown group type.
ofp_error_code_type(group_mod_failed, 11)	-> bad_command;					%% Unsupported or unknown command.
ofp_error_code_type(group_mod_failed, 12)	-> bad_bucket;					%% Error in bucket.
ofp_error_code_type(group_mod_failed, 13)	-> bad_watch;					%% Error in watch port/group
ofp_error_code_type(group_mod_failed, 14)	-> eperm;					%% Permissions error.

ofp_error_code_type(port_mod_failed, 0)		-> bad_port;					%% Specified port number does not exist.
ofp_error_code_type(port_mod_failed, 1)		-> bad_hw_addr;					%% Specified hardware address does not
												%% match the port number.
ofp_error_code_type(port_mod_failed, 2)		-> bad_config;					%% Specified config is invalid.
ofp_error_code_type(port_mod_failed, 3)		-> bad_advertise;				%% Specified advertise is invalid.
ofp_error_code_type(port_mod_failed, 4)		-> eperm;					%% Permissions error.

ofp_error_code_type(table_mod_failed, 0)	-> bad_table;					%% Specified table does not exist.
ofp_error_code_type(table_mod_failed, 1)	-> bad_config;					%% Specified config is invalid.
ofp_error_code_type(table_mod_failed, 2)	-> eperm;					%% Permissions error.

ofp_error_code_type(queue_op_failed, 0)		-> bad_port;					%% Invalid port (or port does not exist).
ofp_error_code_type(queue_op_failed, 1)		-> bad_queue;					%% Queue does not exist.
ofp_error_code_type(queue_op_failed, 2)		-> eperm;					%% Permissions error.

ofp_error_code_type(switch_config_failed, 0)	-> bad_flags;					%% Specified flags is invalid.
ofp_error_code_type(switch_config_failed, 1)	-> bad_len;					%% Specified len is invalid.
ofp_error_code_type(switch_config_failed, 2)	-> eperm;					%% Permissions error.

ofp_error_code_type(role_request_failed, 0)	-> stale;					%% Stale Message: old generation_id.
ofp_error_code_type(role_request_failed, 1)	-> unsup;					%% Controller role change unsupported.
ofp_error_code_type(role_request_failed, 2)	-> bad_role;					%% Invalid role.

ofp_error_code_type(hello_failed, incompatible)		-> 0;
ofp_error_code_type(hello_failed, eperm)		-> 1;

ofp_error_code_type(bad_request, bad_version)		-> 0;
ofp_error_code_type(bad_request, bad_type)		-> 1;
ofp_error_code_type(bad_request, bad_stat)		-> 2;
ofp_error_code_type(bad_request, bad_experimenter)	-> 3;
ofp_error_code_type(bad_request, bad_subtype)		-> 4;
ofp_error_code_type(bad_request, eperm)			-> 5;
ofp_error_code_type(bad_request, bad_len)		-> 6;
ofp_error_code_type(bad_request, buffer_empty)		-> 7;
ofp_error_code_type(bad_request, buffer_unknown)	-> 8;
ofp_error_code_type(bad_request, bad_table_id)		-> 9;
ofp_error_code_type(bad_request, slave)			-> 10;
ofp_error_code_type(bad_request, bad_port)		-> 11;
ofp_error_code_type(bad_request, bad_packet)		-> 12;

ofp_error_code_type(bad_action, bad_type)		-> 0;
ofp_error_code_type(bad_action, bad_len)		-> 1;
ofp_error_code_type(bad_action, bad_experimenter)	-> 2;
ofp_error_code_type(bad_action, bad_experimenter_type)	-> 3;
ofp_error_code_type(bad_action, bad_out_port)		-> 4;
ofp_error_code_type(bad_action, bad_argument)		-> 5;
ofp_error_code_type(bad_action, eperm)			-> 6;
ofp_error_code_type(bad_action, too_many)		-> 7;
ofp_error_code_type(bad_action, bad_queue)		-> 8;
ofp_error_code_type(bad_action, bad_out_group)		-> 9;
ofp_error_code_type(bad_action, match_inconsistent)	-> 10;
ofp_error_code_type(bad_action, unsupported_order)	-> 11;
ofp_error_code_type(bad_action, bad_bad_tag)		-> 12;
ofp_error_code_type(bad_action, bad_set_type)		-> 13;
ofp_error_code_type(bad_action, bad_set_len)		-> 14;
ofp_error_code_type(bad_action, bad_set_argument)	-> 15;

ofp_error_code_type(bad_instruction_code, unknown_inst)		-> 0;
ofp_error_code_type(bad_instruction_code, unsup_inst)		-> 1;
ofp_error_code_type(bad_instruction_code, bad_table_id)		-> 2;
ofp_error_code_type(bad_instruction_code, unsup_metadata)	-> 3;
ofp_error_code_type(bad_instruction_code, unsup_metadata_mask)	-> 4;
ofp_error_code_type(bad_instruction_code, bad_experimenter)	-> 5;
ofp_error_code_type(bad_instruction_code, bad_exp_type)		-> 6;
ofp_error_code_type(bad_instruction_code, bad_len)		-> 7;
ofp_error_code_type(bad_instruction_code, eperm)		-> 8;

ofp_error_code_type(bad_match_code, bad_type)		-> 0;
ofp_error_code_type(bad_match_code, bad_len)		-> 1;
ofp_error_code_type(bad_match_code, bad_tag)		-> 2;
ofp_error_code_type(bad_match_code, bad_dl_addr_mask)	-> 3;
ofp_error_code_type(bad_match_code, bad_nw_addr_mask)	-> 4;
ofp_error_code_type(bad_match_code, bad_wildcards)	-> 5;
ofp_error_code_type(bad_match_code, bad_field)		-> 6;
ofp_error_code_type(bad_match_code, bad_value)		-> 7;
ofp_error_code_type(bad_match_code, bad_mask)		-> 8;
ofp_error_code_type(bad_match_code, bad_prereq)		-> 9;
ofp_error_code_type(bad_match_code, dup_field)		-> 10;
ofp_error_code_type(bad_match_code, eperm)		-> 11;

ofp_error_code_type(flow_mod_failed, unknown)		-> 0;
ofp_error_code_type(flow_mod_failed, tables_full)	-> 1;
ofp_error_code_type(flow_mod_failed, bad_table_id)	-> 2;
ofp_error_code_type(flow_mod_failed, overlap)		-> 3;
ofp_error_code_type(flow_mod_failed, eperm)		-> 4;
ofp_error_code_type(flow_mod_failed, bad_timeout)	-> 5;
ofp_error_code_type(flow_mod_failed, bad_command)	-> 6;
ofp_error_code_type(flow_mod_failed, bad_flags)		-> 7;

ofp_error_code_type(group_mod_failed, group_exists)		-> 0;
ofp_error_code_type(group_mod_failed, invalid_group)		-> 1;
ofp_error_code_type(group_mod_failed, weight_unsupported)	-> 2;
ofp_error_code_type(group_mod_failed, out_of_groups)		-> 3;
ofp_error_code_type(group_mod_failed, out_of_buckets)		-> 4;
ofp_error_code_type(group_mod_failed, chaining_unsupported)	-> 5;
ofp_error_code_type(group_mod_failed, watch_unsupported)	-> 6;
ofp_error_code_type(group_mod_failed, loop)			-> 7;
ofp_error_code_type(group_mod_failed, unknown_group)		-> 8;
ofp_error_code_type(group_mod_failed, chained_group)		-> 9;
ofp_error_code_type(group_mod_failed, bad_type)			-> 10;
ofp_error_code_type(group_mod_failed, bad_command)		-> 11;
ofp_error_code_type(group_mod_failed, bad_bucket)		-> 12;
ofp_error_code_type(group_mod_failed, bad_watch)		-> 13;
ofp_error_code_type(group_mod_failed, eperm)			-> 14;

ofp_error_code_type(port_mod_failed, bad_port)		-> 0;
ofp_error_code_type(port_mod_failed, bad_hw_addr)	-> 1;
ofp_error_code_type(port_mod_failed, bad_config)	-> 2;
ofp_error_code_type(port_mod_failed, bad_advertise)	-> 3;
ofp_error_code_type(port_mod_failed, eperm)		-> 4;

ofp_error_code_type(queue_op_failed, bad_port)		-> 0;
ofp_error_code_type(queue_op_failed, bad_queue)		-> 1;
ofp_error_code_type(queue_op_failed, eperm)		-> 2;

ofp_error_code_type(switch_config_failed, bad_flags)	-> 0;
ofp_error_code_type(switch_config_failed, bad_len)	-> 1;
ofp_error_code_type(switch_config_failed, eperm)	-> 2;

ofp_error_code_type(role_request_failed, stale)		-> 0;
ofp_error_code_type(role_request_failed, unsup)		-> 1;
ofp_error_code_type(role_request_failed, bad_role)	-> 2;

ofp_error_code_type(_, _) -> error.

ofp_capabilities() ->
    [flow_stats, table_stats, port_stats, group_stats, reserved, ip_reasm, queue_stats, reserved, port_blocked].

ofp_action_type() ->
    [output,		%% Output to switch port.
     copy_ttl_out,	%% Copy TTL "outwards" -- from next-to-outermost to outermost
     copy_ttl_in,	%% Copy TTL "inwards" -- from outermost to next-to-outermost
     set_mpls_label,	%% MPLS label
     set_mpls_tc,	%% MPLS TC
     set_mpls_ttl,	%% MPLS TTL
     dec_mpls_ttl,	%% Decrement MPLS TTL
     push_vlan,		%% Push a new VLAN tag
     pop_vlan,		%% Pop the outer VLAN tag
     push_mpls,		%% Push a new MPLS tag
     pop_mpls,		%% Pop the outer MPLS tag
     set_queue,		%% Set queue id when outputting to a port
     group,		%% Apply group.
     set_nw_ttl,	%% IP TTL.
     dec_nw_ttl,	%% Decrement IP TTL.
     push_capwap,
     pop_capwap,
     push_ieee80211,
     pop_ieee80211,
     experimenter].


ofp_port_config() ->
    [port_down, undefined, no_recv, undefined, undefined, no_fwd, no_packet_in].

ofp_port_state() ->
    [link_down, blocked, live].

ofp_port_features() ->
    ['10mb_hd', '10mb_fd', '100mb_hd', '100mb_fd', '1gb_hd', '1gb_fd', '10gb_fd', '40gb_fd', '100gb_fd', '1tb_fd', other, copper, fiber, autoneg, pause, pause_asym].

ofp_packet_in_reason(0)	-> no_match;
ofp_packet_in_reason(1)	-> action;

ofp_packet_in_reason(no_match)	-> 0;
ofp_packet_in_reason(action)	-> 1;

ofp_packet_in_reason(_) -> error.

ofp_config_flags(0)	-> frag_normal;
ofp_config_flags(1)	-> frag_drop;
ofp_config_flags(2)	-> frag_reasm;
ofp_config_flags(4)	-> invalid_ttl_to_controller;

ofp_config_flags(frag_normal)			-> 0;
ofp_config_flags(frag_drop)			-> 1;
ofp_config_flags(frag_reasm)			-> 2;
ofp_config_flags(invalid_ttl_to_controller)	-> 4;

ofp_config_flags(_) -> error.

ofp_instruction_types() ->
    [goto_table, write_metadata, write_actions, apply_actions, clear_actions].

ofp_instruction_type(1)              -> goto_table;
ofp_instruction_type(2)              -> write_metadata;
ofp_instruction_type(3)              -> write_actions;
ofp_instruction_type(4)              -> apply_actions;
ofp_instruction_type(5)              -> clear_actions;
ofp_instruction_type(16#ffff)        -> experimenter;
ofp_instruction_type(goto_table)     -> 1;
ofp_instruction_type(write_metadata) -> 2;
ofp_instruction_type(write_actions)  -> 3;
ofp_instruction_type(apply_actions)  -> 4;
ofp_instruction_type(clear_actions)  -> 5;
ofp_instruction_type(experimenter)   -> 16#ffff.

ofp_flow_mod_command(0)	-> add;
ofp_flow_mod_command(1)	-> modify;
ofp_flow_mod_command(2)	-> modify_strict;
ofp_flow_mod_command(3)	-> delete;
ofp_flow_mod_command(4)	-> delete_strict;

ofp_flow_mod_command(add)		-> 0;
ofp_flow_mod_command(modify)		-> 1;
ofp_flow_mod_command(modify_strict)	-> 2;
ofp_flow_mod_command(delete)		-> 3;
ofp_flow_mod_command(delete_strict)	-> 4;

ofp_flow_mod_command(X) when is_integer(X)	-> X;
ofp_flow_mod_command(_)	-> error.

ofp_flow_mod_flags() ->
    [send_flow_rem, check_overlap, reset_counts].

ofp_table_config() ->
    [miss_controller, miss_continue, miss_drop].

ofp_group_mod_command(0)	-> add;
ofp_group_mod_command(1)	-> modify;
ofp_group_mod_command(2)	-> delete;
ofp_group_mod_command(add)	-> 0;
ofp_group_mod_command(modify)	-> 1;
ofp_group_mod_command(delete)	-> 2.

ofp_group_type(0)		-> all;
ofp_group_type(1)		-> select;
ofp_group_type(2)		-> indirect;
ofp_group_type(3)		-> ff;
ofp_group_type(all)		-> 0;
ofp_group_type(select)		-> 1;
ofp_group_type(indirect)	-> 2;
ofp_group_type(ff)		-> 3.

ofp_group(16#fffffffc)	-> all;
ofp_group(16#ffffffff)	-> any;
ofp_group(X) when is_integer(X) -> X;

ofp_group(all)		-> 16#fffffffc;
ofp_group(any)		-> 16#ffffffff.

-spec dec_ofp_port(non_neg_integer()) -> ofp_port_name() | non_neg_integer().
%% Port numbering.  Physical ports are numbered starting from 1.
dec_ofp_port(16#fffffff8) -> in_port;
dec_ofp_port(16#fffffff9) -> table;
dec_ofp_port(16#fffffffa) -> normal;
dec_ofp_port(16#fffffffb) -> flood;
dec_ofp_port(16#fffffffc) -> all;
dec_ofp_port(16#fffffffd) -> controller;
dec_ofp_port(16#fffffffe) -> local;
dec_ofp_port(16#ffffffff) -> any;
dec_ofp_port(X) when is_integer(X) -> X.

-spec enc_ofp_port(non_neg_integer()) -> non_neg_integer();
		  (ofp_port_name()) -> non_neg_integer().
enc_ofp_port(X) when is_integer(X) -> X;
enc_ofp_port(in_port)    -> 16#fffffff8;
enc_ofp_port(table)      -> 16#fffffff9;
enc_ofp_port(normal)     -> 16#fffffffa;
enc_ofp_port(flood)      -> 16#fffffffb;
enc_ofp_port(all)        -> 16#fffffffc;
enc_ofp_port(controller) -> 16#fffffffd;
enc_ofp_port(local)      -> 16#fffffffe;
enc_ofp_port(any)        -> 16#ffffffff.

ofp_table(16#fe) -> emergency; 
ofp_table(16#ff) -> all;
ofp_table(X) when is_integer(X) -> X;
ofp_table(emergency) -> 16#fe;
ofp_table(all)       -> 16#ff.

ofp_queue(16#ffff) -> all;
ofp_queue(X) when is_integer(X) -> X;
ofp_queue(all)      -> 16#ffff.

ofp_flow_removed_reason(0) -> idle_timeout;
ofp_flow_removed_reason(1) -> hard_timeout;
ofp_flow_removed_reason(2) -> delete;
ofp_flow_removed_reason(3) -> group_delete;
ofp_flow_removed_reason(X) when is_integer(X) -> X;

ofp_flow_removed_reason(idle_timeout) -> 0;
ofp_flow_removed_reason(hard_timeout) -> 1;
ofp_flow_removed_reason(delete)       -> 2;
ofp_flow_removed_reason(group_delete) -> 3.

ofp_port_reason(0) -> add;
ofp_port_reason(1) -> delete;
ofp_port_reason(2) -> modify;
ofp_port_reason(X) when is_integer(X) -> X;
ofp_port_reason(add)    -> 0;
ofp_port_reason(delete) -> 1;
ofp_port_reason(modify) -> 2.

ofp_stats_type(0)		-> desc;
ofp_stats_type(1)		-> flow;
ofp_stats_type(2)		-> aggregate;
ofp_stats_type(3)		-> table;
ofp_stats_type(4)		-> port;
ofp_stats_type(5)		-> queue;
ofp_stats_type(16#ffff)		-> experimenter;
ofp_stats_type(X) when is_integer(X) -> X;
ofp_stats_type(desc)		-> 0;
ofp_stats_type(flow)		-> 1;
ofp_stats_type(aggregate)	-> 2;
ofp_stats_type(table)		-> 3;
ofp_stats_type(port)		-> 4;
ofp_stats_type(queue)		-> 5;
ofp_stats_type(experimenter)	-> 16#ffff;
ofp_stats_type(vendor)		-> 16#ffff.

ofp_queue_properties(0)        -> none;
ofp_queue_properties(1)        -> min_rate;
ofp_queue_properties(2)        -> max_rate;
ofp_queue_properties(none)     -> 0;
ofp_queue_properties(min_rate) -> 1;
ofp_queue_properties(max_rate) -> 2.

ofp_experimenter_stats_type(ExperimenterStatsType)	-> ExperimenterStatsType.

-spec of_experimenter_ext(of_experimenter_ext()) -> {atom(), non_neg_integer()};
			 ({atom(), non_neg_integer()}) -> of_experimenter_ext().
of_experimenter_ext({rofl, 0}) ->	rofl_none;
of_experimenter_ext({rofl, 2}) ->	rofl_flowspace;
of_experimenter_ext(rofl_none) ->	{rofl, 0};
of_experimenter_ext(rofl_flowspace) ->	{rofl, 2};
of_experimenter_ext(ExperimenterExt) when is_integer(ExperimenterExt) ->	ExperimenterExt.

%% protocol(NwProto)
%%   when is_atom(NwProto) ->
%%     gen_socket:protocol(NwProto);
%% protocol(NwProto) ->
%%     NwProto.

%%%===================================================================
%%% Decode
%%%===================================================================
decode_msg(error, << Type:16/integer, Code:16/integer, Data/binary >>) ->
    Type1 = ofp_error_type(Type),
    Code1 = ofp_error_code_type(Type1, Code),
    Error = {Type1, Code1},
    #ofp_error{error = Error, data = Data};

decode_msg(experimenter, << Experimenter:32/integer, Cmd:32/integer, Data/binary >>) ->
    decode_msg(of_experimenter_ext({experimenter(Experimenter), Cmd}), Data);

decode_msg(features_reply, <<DataPathId:64/integer, NBuffers:32/integer, NTables:8/integer, Pad:3/bytes,
			     Capabilities:32/integer, _Reserved:32/integer, Ports/binary>>) ->
    lager:debug("DataPathId: ~p, NBuffers: ~p, NTables: ~p, Pad: ~p, Capabilities: ~p, Ports: ~p",
	   [DataPathId, NBuffers, NTables, Pad, Capabilities, Ports]),
    #ofp_switch_features{datapath_id = DataPathId,
			 n_buffers = NBuffers,
			 n_tables = NTables,
			 capabilities = dec_flags(ofp_capabilities(), Capabilities),
			 actions = [],
			 ports = decode_phy_ports(Ports)};

decode_msg(get_config_reply, <<Flags:16/integer, MissSendLen:16/integer>>) ->
    #ofp_switch_config{flags = ofp_config_flags(Flags), miss_send_len = MissSendLen};

decode_msg(set_config, <<Flags:16/integer, MissSendLen:16/integer>>) ->
    #ofp_switch_config{flags = ofp_config_flags(Flags), miss_send_len = MissSendLen};

decode_msg(packet_in, <<BufferId:32/integer, TotalLen:16/integer, Reason:8/integer, TableId:8/integer, Rest/binary>>) ->
    <<_MatchType:16/integer, MatchLength:16/integer, _/binary>> = Rest,
    PadLength = pad_length(8, MatchLength) + 2,
    <<Match:MatchLength/bytes, _Pad:PadLength/bytes, Data/binary>> = Rest,

    #ofp_packet_in_v12{buffer_id = BufferId, total_len = TotalLen, reason = ofp_packet_in_reason(Reason),
		       table_id = TableId, match = decode_ofp_match(Match), data = Data};

decode_msg(flow_removed, <<Cookie:64/integer, Priority:16/integer, Reason:8/integer, TableId:8/integer,
			   DurationSec:32/integer, DurationNSec:32/integer, IdleTimeout:16/integer, HardTimeout:16/integer,
			   PacketCount:64/integer, ByteCount:64/integer, Match/binary>>) ->
    #ofp_flow_removed_v12{cookie = Cookie, priority = Priority, reason = ofp_flow_removed_reason(Reason), table_id = TableId,
			  duration = {DurationSec, DurationNSec}, idle_timeout = IdleTimeout, hard_timeout = HardTimeout,
			  packet_count = PacketCount, byte_count = ByteCount, match = decode_ofp_match(Match)};

decode_msg(port_status, <<Reason:8/integer, _Pad:7/bytes, PhyPort/binary>>) ->
    #ofp_port_status{reason = ofp_port_reason(Reason),
		     port = decode_phy_port(PhyPort)};

decode_msg(packet_out, <<BufferId:32/integer, InPort:32/integer, ActionsLen:16/integer, _Pad:6/bytes, Actions:ActionsLen/bytes, Data/binary>>) ->
    #ofp_packet_out{buffer_id = BufferId, in_port = dec_ofp_port(InPort), actions = decode_actions(Actions), data = Data};

decode_msg(flow_mod, <<Cookie:64/integer, CookieMask:64/integer, TableId:8/integer,
		       Command:8/integer, IdleTimeout:16/integer, HardTimeout:16/integer,
		       Priority:16/integer, BufferId:32/integer, OutPort:32/integer,
		       OutGroup:32/integer, Flags:16/integer, _Pad1:2/bytes,
		       Rest/binary>>) ->
    <<_MatchType:16/integer, MatchLength:16/integer, _/binary>> = Rest,
    PadLength = pad_length(8, MatchLength),
    <<Match:MatchLength/bytes, _Pad:PadLength/bytes, Instructions/binary>> = Rest,
    #ofp_flow_mod_v12{cookie = Cookie, cookie_mask = CookieMask, table_id = TableId,
		      command = ofp_flow_mod_command(Command),
		      idle_timeout = IdleTimeout, hard_timeout = HardTimeout,
		      priority = Priority, buffer_id = BufferId,
		      out_port = dec_ofp_port(OutPort), out_group = ofp_group(OutGroup),
		      flags = dec_flags(ofp_flow_mod_flags(), Flags),
		      match = decode_ofp_match(Match),
		      instructions = decode_ofp_instructions(Instructions)};

decode_msg(group_mod, <<Command:16/integer, Type:8/integer, _Pad:1/bytes,
			GroupId:32/integer, Buckets/binary>>) ->
    #ofp_group_mod{command = ofp_group_mod_command(Command),
		   type = ofp_group_type(Type),
		   group_id = GroupId,
		   buckets = decode_ofp_buckets(Buckets)};

decode_msg(port_mod, <<PortNo:32/integer, _Pad0:4/bytes, HwAddr:6/bytes, _Pad1:2/bytes,
		       Config:32/integer, Mask:32/integer, Advertise:32/integer, _Pad2:4/bytes>>) ->
    #ofp_port_mod{port_no = PortNo, hw_addr = HwAddr,
		  config = dec_flags(ofp_port_config(), Config),
		  mask = dec_flags(ofp_port_config(), Mask),
		  advertise = dec_flags(ofp_port_features(), Advertise)};

decode_msg(stats_request, <<Type:16/integer, _Flags:16/integer, _Pad:4/bytes, Msg/binary>>) ->
    decode_stats_request(ofp_stats_type(Type), Msg);

decode_msg(stats_reply, <<Type:16/integer, _Flags:16/integer, _Pad:4/bytes, Msg/binary>>) ->
    decode_stats_reply(ofp_stats_type(Type), [], Msg);

decode_msg(queue_get_config_request, <<Port:32/integer, _Pad:4/bytes>>) ->
    #ofp_queue_get_config_request{port = dec_ofp_port(Port)};

decode_msg(ofp_queue_get_config_reply, <<Port:32/integer, _Pad:4/bytes, Queues/binary>>) ->
    #ofp_queue_get_config_reply{port = dec_ofp_port(Port), queues = decode_queues(Queues)};

%%---------------------------
%% Experimenter Extensions
%%---------------------------
decode_msg(rofl_flowspace, <<1:8, 2:8, Length:16/integer, Data/binary>>) ->
    MsgSize = Length - 4,
    <<Msg:MsgSize/bytes, _Pad/binary>> = Data,
    decode_rofl_flowspace(Msg);

decode_msg(_, Msg) ->
    Msg.

%%---------------------------
%% Experimenter Extensions
%%---------------------------
decode_rofl_flowspace(<<1:8/integer, _Pad:3/bytes, Match/binary>>) ->
    #rofl_flowspace{action = add, match = decode_ofp_match(Match)};
decode_rofl_flowspace(<<2:8/integer, _Pad:3/bytes, Match/binary>>) ->
    #rofl_flowspace{action = del, match = decode_ofp_match(Match)}.

-define(DECODE_OXM_TLV(Class, Field, Length, Type, Atom),
	decode_oxm_tlv(<<Class:16/integer, Field:7/integer, 0:1,
			 (Length div 8):8/integer,
			 Value:Length/Type, Next/binary>>) ->
	       {{Atom, Value}, Next}).

-define(DECODE_OXM_TLV_MAP(Class, Field, Length, Type, Atom, MAP),
	decode_oxm_tlv(<<Class:16/integer, Field:7/integer, 0:1,
			 (Length div 8):8/integer,
			 Value:Length/Type, Next/binary>>) ->
	       {{Atom, MAP(Value)}, Next}).

-define(DECODE_OXM_MASK_TLV(Class, Field, Length, Type, Atom),
	decode_oxm_tlv(<<Class:16/integer, Field:7/integer, 1:1,
			 (Length div 4):8/integer,
			 Value:Length/Type, Mask:Length/Type, Next/binary>>) ->
	       {{Atom, Value, Mask}, Next}).

?DECODE_OXM_TLV_MAP(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IN_PORT, 32, integer, in_port, dec_ofp_port);
?DECODE_OXM_TLV_MAP(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IN_PHY_PORT, 32, integer, in_phy_port, dec_ofp_port);
?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_METADATA, 64, bits, metadata);
?DECODE_OXM_MASK_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_METADATA, 64, bits, metadata);
?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ETH_DST, 48, bits, eth_dst);
?DECODE_OXM_MASK_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ETH_DST, 48, bits, eth_dst);
?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ETH_SRC, 48, bits, eth_src);
?DECODE_OXM_MASK_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ETH_SRC, 48, bits, eth_src);
?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ETH_TYPE, 16, integer, eth_type);

decode_oxm_tlv(<<?OFPXMC_OPENFLOW_BASIC:16/integer,
		 ?OFPXMT_OFB_VLAN_VID:7/integer, 0:1, 2:8/integer,
		 16#0000:16/integer, Next/binary>>) ->
    {{vlan_vid, none}, Next};

decode_oxm_tlv(<<?OFPXMC_OPENFLOW_BASIC:16/integer,
		 ?OFPXMT_OFB_VLAN_VID:7/integer, 0:1, 2:8/integer,
		 Value:16/integer, Next/binary>>) ->
    {{vlan_vid, Value}, Next};

decode_oxm_tlv(<<?OFPXMC_OPENFLOW_BASIC:16/integer,
		 ?OFPXMT_OFB_VLAN_VID:7/integer, 1:1, 4:8/integer,
		 16#1000:16/integer, 16#1000:16/integer, Next/binary>>) ->
    {{vlan_vid, present}, Next};

?DECODE_OXM_MASK_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_VLAN_VID, 2, bits, vlan_vid);

decode_oxm_tlv(<<?OFPXMC_OPENFLOW_BASIC:16/integer,
		 ?OFPXMT_OFB_VLAN_PCP:7/integer, 0:1, 1:8/integer,
		 _:5, Value:3/integer, Next/binary>>) ->
    {{vlan_pcp, Value}, Next};

decode_oxm_tlv(<<?OFPXMC_OPENFLOW_BASIC:16/integer,
		 ?OFPXMT_OFB_IP_DSCP:7/integer, 0:1, 1:8/integer,
		 _:2, Value:6/integer, Next/binary>>) ->
    {{ip_dscp, Value}, Next};

decode_oxm_tlv(<<?OFPXMC_OPENFLOW_BASIC:16/integer,
		 ?OFPXMT_OFB_IP_ECN:7/integer, 0:1, 1:8/integer,
		 _:6, Value:2/integer, Next/binary>>) ->
    {{ip_ecn, Value}, Next};

?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IP_PROTO, 8, integer, ip_proto);
?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IPV4_SRC, 32, bits, ipv4_src);
?DECODE_OXM_MASK_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IPV4_SRC, 32, bits, ipv4_src);
?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IPV4_DST, 32, bits, ipv4_dst);
?DECODE_OXM_MASK_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IPV4_DST, 32, bits, ipv4_dst);
?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_TCP_SRC, 16, integer, tcp_src);
?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_TCP_DST, 16, integer, tcp_dst);
?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_UDP_SRC, 16, integer, udp_src);
?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_UDP_DST, 16, integer, udp_dst);
?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_SCTP_SRC, 16, integer, sctp_src);
?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_SCTP_DST, 16, integer, sctp_dst);
?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ICMPV4_TYPE, 8, integer, icmpv4_type);
?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ICMPV4_CODE, 8, integer, icmpv4_code);
?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ARP_OP, 16, integer, arp_op);
?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ARP_SPA, 32, bits, arp_spa);
?DECODE_OXM_MASK_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ARP_SPA, 32, bits, arp_spa);
?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ARP_TPA, 32, bits, arp_tpa);
?DECODE_OXM_MASK_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ARP_TPA, 32, bits, arp_tpa);
?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ARP_SHA, 48, bits, arp_sha);
?DECODE_OXM_MASK_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ARP_SHA, 48, bits, arp_sha);
?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ARP_THA, 48, bits, arp_tha);
?DECODE_OXM_MASK_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ARP_THA, 48, bits, arp_tha);
?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IPV6_SRC, 128, bits, ipv6_src);
?DECODE_OXM_MASK_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IPV6_SRC, 128, bits, ipv6_src);
?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IPV6_DST, 128, bits, ipv6_dst);
?DECODE_OXM_MASK_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IPV6_DST, 128, bits, ipv6_dst);

decode_oxm_tlv(<<?OFPXMC_OPENFLOW_BASIC:16/integer,
		 ?OFPXMT_OFB_IPV6_FLABEL:7/integer, 0:1, 4:8/integer,
		 _:4, Value:20/integer, _:4, Next/binary>>) ->
    {{ipv6_flabel, Value}, Next};

decode_oxm_tlv(<<?OFPXMC_OPENFLOW_BASIC:16/integer,
		 ?OFPXMT_OFB_IPV6_FLABEL:7/integer, 1:1, 8:8/integer,
		 _:4, Value:20/integer, _:4, Mask:20/integer, Next/binary>>) ->
    {{ipv6_flabel, Value, Mask}, Next};

?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ICMPV6_TYPE, 8, integer, icmpv6_type);
?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ICMPV6_CODE, 8, integer, icmpv6_code);
?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IPV6_ND_TARGET, 128, bits, ipv6_nd_target);
?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IPV6_ND_SLL, 48, bits, ipv6_nd_sll);
?DECODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IPV6_ND_TLL, 48, bits, ipv6_nd_tll);

decode_oxm_tlv(<<?OFPXMC_OPENFLOW_BASIC:16/integer,
		 ?OFPXMT_OFB_MPLS_LABEL:7/integer, 0:1, 4:8/integer,
		 _:4, Value:20/integer, Next/binary>>) ->
    {{mpls_flabel, Value}, Next};

decode_oxm_tlv(<<?OFPXMC_OPENFLOW_BASIC:16/integer,
		 ?OFPXMT_OFB_MPLS_TC:7/integer, 0:1, 1:8/integer,
		 _:5, Value:3/integer, Next/binary>>) ->
    {{mpls_tc, Value}, Next};

?DECODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_PPPOE_CODE, 8, integer, pppoe_code);
?DECODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_PPPOE_TYPE, 8, integer, pppoe_type);
?DECODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_PPPOE_SID, 16, integer, pppoe_sid);
?DECODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_PPP_PROT, 16, integer, ppp_prot);

?DECODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_GTP_MSG_TYPE, 8, integer, gtp_msg_type);
?DECODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_GTP_TEID, 32, bits, gtp_teid);
?DECODE_OXM_MASK_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_GTP_TEID, 32, bits, gtp_teid);

?DECODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_CAPWAP_WBID, 8, integer, capwap_wbid);
?DECODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_CAPWAP_RID, 8, integer, capwap_rid);
?DECODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_CAPWAP_FLAGS, 16, integer, capwap_flags);
?DECODE_OXM_MASK_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_CAPWAP_FLAGS, 16, integer, capwap_flags);

?DECODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_IEEE80211_FC, 16, integer, ieee80211_fc);
?DECODE_OXM_MASK_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_IEEE80211_FC, 16, integer, ieee80211_fc);
?DECODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_IEEE80211_TYPE, 8, integer, ieee80211_type);
?DECODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_IEEE80211_SUBTYPE, 8, integer, ieee80211_subtype);
?DECODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_IEEE80211_DIRECTION, 8, integer, ieee80211_direction);
?DECODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_IEEE80211_ADDRESS_1, 48, bits, ieee80211_address_1);
?DECODE_OXM_MASK_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_IEEE80211_ADDRESS_1, 48, bits, ieee80211_address_1);
?DECODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_IEEE80211_ADDRESS_2, 48, bits, ieee80211_address_2);
?DECODE_OXM_MASK_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_IEEE80211_ADDRESS_2, 48, bits, ieee80211_address_2);
?DECODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_IEEE80211_ADDRESS_3, 48, bits, ieee80211_address_3);
?DECODE_OXM_MASK_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_IEEE80211_ADDRESS_3, 48, bits, ieee80211_address_3);

decode_oxm_tlv(<<Class:16/integer, Field:7/integer, 0:1, Length:8/integer, Rest/binary>>) ->
    <<Value:Length/binary, Next/binary>> = Rest,
    {{{Class, Field}, Value}, Next};

decode_oxm_tlv(<<Class:16/integer, Field:7/integer, 1:1, Length:8/integer, Rest/binary>>) ->
    L = Length div 2,
    <<Value:L/binary, Mask:L/binary, Next/binary>> = Rest,
    {{{Class, Field}, {Value, Mask}}, Next};
decode_oxm_tlv(Data) ->
    {Data, <<>>}.

decode_oxm_tlvs(<<>>, TLVs) ->
    lists:reverse(TLVs);
decode_oxm_tlvs(Data, TLVs) ->
    {TLV, Next} = decode_oxm_tlv(Data),
    decode_oxm_tlvs(Next, [TLV|TLVs]).

-spec decode_ofp_match(Match :: binary()) -> [oxm_tlv()].
decode_ofp_match(<<?OFPMT_OXM:16/integer, Length:16/integer, Match/binary>>) ->
    TLVLen = Length - 4,
    <<TLVs:TLVLen/binary, _Padding/binary>> = Match,
    decode_oxm_tlvs(TLVs, []).

-spec decode_ofp_instructions(Instructions :: binary()) -> [ofp_instructions()].
decode_ofp_instructions(Instructions) ->
    decode_ofp_instructions(Instructions, []).

decode_ofp_instructions(<<>>, Acc) ->
    lists:reverse(Acc);
decode_ofp_instructions(<<Type:16/integer, Len:16/integer, Rest/binary>>, Acc) ->
    PayLoadLen = Len - 4,
    <<PayLoad:PayLoadLen/bytes, Next/binary>> = Rest,
    decode_ofp_instructions(Next, [decode_ofp_instruction(ofp_instruction_type(Type), PayLoad)|Acc]).
decode_ofp_instruction(goto_table, <<TableId:8/integer, _Pad:3/bytes>>) ->
    #ofp_instruction_goto_table{table_id = TableId};
decode_ofp_instruction(write_metadata, <<_Pad:32, MetaData:64/integer, MetaDataMask:64/integer>>) ->
    #ofp_instruction_write_metadata{metadata = MetaData, metadata_mask = MetaDataMask};
decode_ofp_instruction(Type, <<_Pad:4/bytes, Actions/binary>>) ->
    #ofp_instruction_actions{type = Type, actions = decode_actions(Actions)}.

decode_ofp_buckets(Buckets) ->
    decode_ofp_buckets(Buckets, []).

decode_ofp_buckets(<<>>, Acc) ->
    lists:reverse(Acc);
decode_ofp_buckets(<<Len:16/integer, Weight:16/integer, WatchPort:32/integer,
		     WatchGroup:32/integer, _Pad:4/bytes, Rest/binary>>, Acc) ->
    ActionsLen = Len - 16,
    <<Actions:ActionsLen/bytes, Next>> = Rest,
    Bucket = #ofp_bucket{weight = Weight, watch_port = dec_ofp_port(WatchPort),
			 watch_group = WatchGroup, actions = decode_actions(Actions)},
    decode_ofp_buckets(Next, [Bucket|Acc]).

decode_experimenter_action(travelping, <<?OFXAT_TP_PUSH_CAPWAP:16/integer, _/binary>>) ->
    #ofp_action_push_capwap{};
decode_experimenter_action(travelping, <<?OFXAT_TP_POP_CAPWAP:16/integer, _/binary>>) ->
    #ofp_action_pop_capwap{};
decode_experimenter_action(travelping, <<?OFXAT_TP_PUSH_IEEE80211:16/integer, _/binary>>) ->
    #ofp_action_push_ieee80211{};
decode_experimenter_action(travelping, <<?OFXAT_TP_POP_IEEE80211:16/integer, _/binary>>) ->
    #ofp_action_pop_ieee80211{};

decode_experimenter_action(Experimenter, Msg) ->
    #ofp_action_experimenter{experimenter = Experimenter, msg = Msg}.

-spec decode_action(Type :: non_neg_integer(), Length :: non_neg_integer(), binary()) -> ofp_action().
decode_action(?OFP12AT_OUTPUT, 12, <<Port:32/integer, MaxLen:16/integer, _:48>>) ->
    #ofp_action_output{port = dec_ofp_port(Port), max_len = MaxLen};
decode_action(1, 4, <<VlanVid:16/integer, _:16>>) ->
    #ofp_action_vlan_vid{vlan_vid = VlanVid};
decode_action(?OFP12AT_COPY_TTL_OUT, 0, <<>>) ->
    #ofp_action_copy_ttl_out{};
decode_action(?OFP12AT_COPY_TTL_IN, 0, <<_:32>>) ->
    #ofp_action_copy_ttl_in{};
decode_action(13, 4, <<MplsLabel:32/integer>>) ->
    #ofp_action_set_mpls_label{label = MplsLabel};
decode_action(14, 4, <<MplsTc:8/integer, _:24>>) ->
    #ofp_action_set_mpls_tc{tc = MplsTc};
decode_action(?OFP12AT_SET_MPLS_TTL, 4, <<MplsTtl:8/integer, _:24>>) ->
    #ofp_action_set_mpls_ttl{ttl = MplsTtl};
decode_action(?OFP12AT_DEC_MPLS_TTL, 0, <<>>) ->
    #ofp_action_dec_mpls_ttl{};
decode_action(?OFP12AT_PUSH_VLAN, 4, <<EtherType:16/integer, _:16>>) ->
    #ofp_action_push_vlan{ethertype = EtherType};
decode_action(?OFP12AT_POP_VLAN, 0, <<_:32>>) ->
    #ofp_action_pop_vlan{};
decode_action(?OFP12AT_PUSH_MPLS, 4, <<EtherType:16/integer, _:16>>) ->
    #ofp_action_push_mpls{ethertype = EtherType};
decode_action(?OFP12AT_POP_MPLS, 4, <<EtherType:16/integer, _:16>>) ->
    #ofp_action_pop_mpls{ethertype = EtherType};
decode_action(?OFP12AT_SET_QUEUE, 4, <<QueueId:32/integer>>) ->
    #ofp_action_set_queue{queue_id = QueueId};
decode_action(?OFP12AT_GROUP, 4, <<GroupId:32/integer>>) ->
    #ofp_action_group{group_id = GroupId};
decode_action(?OFP12AT_SET_NW_TTL, 4, <<NwTtl:8/integer, _:24>>) ->
    #ofp_action_set_nw_ttl{ttl = NwTtl};
decode_action(?OFP12AT_DEC_NW_TTL, 0, <<_:32>>) ->
    #ofp_action_dec_nw_ttl{};
decode_action(?OFP12AT_SET_FIELD, _, Data) ->
    {TLV, _} = decode_oxm_tlv(Data),
    #ofp_action_set_field{tlv = TLV};

decode_action(16#FFFF, Length, <<Experimenter:32, Msg/binary>> = PayLoad)
  when Length == size(PayLoad) ->
    decode_experimenter_action(experimenter(Experimenter), Msg);
decode_action(Type, Length, Msg)
  when Length == size(Msg) ->
    {Type, Msg}.

decode_actions(<<>>, Acc) ->
    lists:reverse(Acc);
decode_actions(<<Type:16/integer, Length:16/integer, Rest/binary>>, Acc) ->
    Len = Length - 4,
    <<Msg:Len/bytes, Next/binary>> = Rest,
    decode_actions(Next, [decode_action(Type, Len, Msg)|Acc]).

decode_actions(Msg) ->
    decode_actions(Msg, []).

decode_phy_port(<<PortNo:32/integer, _Pad1:4/bytes,
		  HwAddr:6/binary, _Pad2:2/bytes, Name:16/binary,
		  Config:32/integer, State:32/integer,
		  Curr:32/integer, Advertised:32/integer,
		  Supported:32/integer, Peer:32/integer,
		  CurrSpeed:32/integer, MaxSpeed:32/integer>>) ->
    #ofp_phy_port{port_no = dec_ofp_port(PortNo),
		  hw_addr = HwAddr,
		  name = decode_binstring(Name),
		  config = dec_flags(ofp_port_config(), Config),
		  state = dec_flags(ofp_port_state(), State),
		  curr = dec_flags(ofp_port_features(), Curr),
		  advertised = dec_flags(ofp_port_features(), Advertised),
		  supported = dec_flags(ofp_port_features(), Supported),
		  peer = dec_flags(ofp_port_features(), Peer),
		  curr_speed = CurrSpeed, max_speed = MaxSpeed}.

decode_phy_ports(Msg) ->
    [ decode_phy_port(Port) || <<Port:64/binary>> <= Msg].

decode_queue_prop(none, <<>>) ->
    none;
decode_queue_prop(min_rate, <<Rate:16/integer, _Pad:6/bytes>>) ->
    #ofp_queue_prop_min_rate{rate = Rate};
decode_queue_prop(max_rate, <<Rate:16/integer, _Pad:6/bytes>>) ->
    #ofp_queue_prop_max_rate{rate = Rate}.

decode_queue_props(<<>>, Acc) ->
    lists:reverse(Acc);
decode_queue_props(<<Property:16/integer, Len:16/integer, _Pad:4/bytes, Data>>, Acc) ->
    PropLen = Len - 8,
    <<Prop:PropLen/bytes, Rest/binary>> = Data,
    decode_queue_props(Rest, [decode_queue_prop(ofp_queue_properties(Property), Prop)|Acc]).

decode_queues(<<>>, Acc) ->
    lists:reverse(Acc);
decode_queues(<<QueueId:32/integer, Port:32/integer, Len:16/integer, _Pad:6/bytes, Data/binary>>, Acc) ->
    DescLen = Len - 8,
    <<Desc:DescLen/bytes, Rest/binary>> = Data,
    Properties = decode_queues(Rest, [decode_queue_props(Desc, [])|Acc]),
    #ofp_packet_queue_v12{queue_id = QueueId, port = dec_ofp_port(Port), properties = Properties}.

decode_queues(Queues) ->
    decode_queues(Queues, []).

decode_binstring(Str) ->
    [Name|_Rest] = binary:split(Str, <<0>>),
    Name.

%% Stats Reques/Reply

decode_stats_request(desc, <<>>) ->
    #ofp_desc_stats_request{};

decode_stats_request(flow, <<TableId:8/integer, _Pad0:3/bytes, OutPort:32/integer, OutGroup:32/integer,
			     _Pad1:4/bytes, Cookie:64/integer, CookieMask:64/integer, Match/binary>>) ->
    #ofp_flow_stats_request_v11{table_id = ofp_table(TableId), out_port = dec_ofp_port(OutPort),
				out_group = ofp_group(OutGroup), cookie = Cookie, cookie_mask = CookieMask,
				match = decode_ofp_match(Match)};

decode_stats_request(aggregate, <<TableId:8/integer, _Pad0:3/bytes, OutPort:32/integer, OutGroup:32/integer,
			     _Pad1:4/bytes, Cookie:64/integer, CookieMask:64/integer, Match/binary>>) ->
    #ofp_aggregate_stats_request_v11{table_id = ofp_table(TableId), out_port = dec_ofp_port(OutPort),
				     out_group = ofp_group(OutGroup), cookie = Cookie, cookie_mask = CookieMask,
				     match = decode_ofp_match(Match)};

decode_stats_request(table, <<>>) ->
    #ofp_table_stats_request{};
%% broken ROFL stats request
decode_stats_request(table, Value)
  when is_binary(Value) ->
    #ofp_rofl_broken_table_stats_request{};

decode_stats_request(port, <<Port:32/integer, _Pad:4/bytes>>) ->
    #ofp_port_stats_request{port_no = dec_ofp_port(Port)};

decode_stats_request(queue, <<Port:32/integer, Queue:32/integer>>) ->
    #ofp_queue_stats_request{port_no = dec_ofp_port(Port), queue_id = ofp_queue(Queue)};

decode_stats_request(group, <<GroupId:32/integer, _Pad:4/bytes>>) ->
    #ofp_group_stats_request{group_id = GroupId};

decode_stats_request(group_desc, <<>>) ->
    #ofp_group_desc_stats_request{};

decode_stats_request(group_features, <<>>) ->
    #ofp_group_features_request{};

decode_stats_request(experimenter, <<Experimenter:32/integer, Msg/binary>>) ->
    decode_experimenter_stats_request(experimenter(Experimenter), Msg).

decode_experimenter_stats_request(Experimenter, <<SubType:32/integer, _Pad:4/bytes, Msg/binary>>) ->
    decode_stats_request(ofp_experimenter_stats_type({Experimenter, SubType}), Msg).

decode_stats_reply(_, Acc, <<>>) ->
    lists:reverse(Acc);

decode_stats_reply(desc, Acc, <<MfrDesc:256/bytes, HwDesc:256/bytes, SwDesc:256/bytes,
				SerialNum:32/bytes, DpDesc:256/bytes, Rest/binary>>) ->
    R = #ofp_desc_stats{mfr_desc = decode_binstring(MfrDesc), hw_desc = decode_binstring(HwDesc),
			sw_desc = decode_binstring(SwDesc), serial_num = decode_binstring(SerialNum),
			dp_desc = decode_binstring(DpDesc)},
    decode_stats_reply(desc, [R|Acc], Rest);

decode_stats_reply(flow, Acc, <<Length:16/integer, TableId:8/integer, _Pad0:1/bytes, Sec:32/integer, NSec:32/integer,
				Priority:16/integer, IdleTimeout:16/integer, HardTimeout:16/integer, _Pad2:6/bytes,
				Cookie:64/integer, PacketCount:64/integer, ByteCount:64/integer, More/binary>>) ->

    RestLength = Length - 48,
    <<Rest:RestLength/bytes, Next/binary>> = More,
    <<_MatchType:16/integer, MatchLength:16/integer, _/binary>> = Rest,
    PadLength = pad_length(8, MatchLength),
    <<Match:MatchLength/bytes, _Pad:PadLength/bytes, Instructions/binary>> = Rest,

    R = #ofp_flow_stats_v11{table_id = ofp_table(TableId), duration = {Sec, NSec},
			    priority = Priority,
			    idle_timeout = IdleTimeout, hard_timeout = HardTimeout, cookie = Cookie,
			    packet_count = PacketCount, byte_count = ByteCount,
			    match = decode_ofp_match(Match), instructions = decode_ofp_instructions(Instructions)},
    decode_stats_reply(flow, [R|Acc], Next);

decode_stats_reply(aggregate, Acc, <<PacketCount:64/integer, ByteCount:64/integer, FlowCount:32/integer, _Pad:4/bytes, Rest/binary>>) ->
    R = #ofp_aggregate_stats{packet_count = PacketCount, byte_count = ByteCount,
			     flow_count = FlowCount},
    decode_stats_reply(aggregate, [R|Acc], Rest);

decode_stats_reply(table, Acc, <<TableId:8/integer, _Pad:7/bytes, Name:32/bytes, Wildcards:32/integer,
				 Match:32/integer, Instructions:32/integer, WriteActions:32/integer,
				 ApplyActions:32/integer, Config:32/integer, MaxEntries:32/integer,
				 ActiveCount:32/integer, LookupCount:64/integer, MatchedCount:64/integer,
				 Rest/binary>>)
  when Rest == <<>> ->
    R = #ofp_rofl_broken_table_stats_v12{
      table_id = ofp_table(TableId), name = decode_binstring(Name),
      wildcards = Wildcards, match = Match, 
      instructions = dec_flags(ofp_instruction_types(), Instructions),
      write_actions = dec_flags(ofp_action_type(), WriteActions),
      apply_actions = dec_flags(ofp_action_type(), ApplyActions),
      config = Config, max_entries = MaxEntries,
      active_count = ActiveCount, lookup_count = LookupCount, matched_count = MatchedCount},
    decode_stats_reply(table, [R|Acc], Rest);

decode_stats_reply(table, Acc, <<TableId:8/integer, _Pad:7/bytes, Name:32/bytes,
				 Match:64/integer, Wildcards:64/integer,
				 WriteActions:32/integer, ApplyActions:32/integer,
				 WriteSetFields:64/integer, ApplySetFields:64/integer,
				 MetadataMatch:64/integer, MetadataWrite:64/integer,
				 Instructions:32/integer, Config:32/integer, MaxEntries:32/integer,
				 ActiveCount:32/integer, LookupCount:64/integer, MatchedCount:64/integer,
				 Rest/binary>>) ->


    R = #ofp_table_stats_v12{table_id = ofp_table(TableId), name = decode_binstring(Name),
			     match = dec_flags(ofp_xmt_type(), Match),
			     wildcards = dec_flags(ofp_xmt_type(), Wildcards),
			     write_actions = dec_flags(ofp_action_type(), WriteActions),
			     apply_actions = dec_flags(ofp_action_type(), ApplyActions),
			     write_setfields = dec_flags(ofp_xmt_type(), WriteSetFields),
			     apply_setfields = dec_flags(ofp_xmt_type(), ApplySetFields),
			     metadata_match = MetadataMatch, metadata_write = MetadataWrite,
			     instructions = dec_flags(ofp_instruction_types(), Instructions),
			     config = Config, max_entries = MaxEntries,
			     active_count = ActiveCount, lookup_count = LookupCount, matched_count = MatchedCount},
    decode_stats_reply(table, [R|Acc], Rest);

decode_stats_reply(port, Acc, <<Port:32/integer, _Pad:4/bytes, RxPackets:64/integer, TxPackets:64/integer,
				RxBytes:64/integer, TxBytes:64/integer, RxDropped:64/integer, TxDropped:64/integer,
				RxErrors:64/integer, TxErrors:64/integer, RxFrameErr:64/integer, RxOverErr:64/integer,
				RxCrcErr:64/integer, Collisions:64/integer, Rest/binary>>) ->
    R = #ofp_port_stats{port_no = dec_ofp_port(Port), rx_packets = RxPackets, tx_packets = TxPackets,
			rx_bytes = RxBytes, tx_bytes = TxBytes, rx_dropped = RxDropped,
			tx_dropped = TxDropped,	rx_errors = RxErrors, tx_errors = TxErrors,
			rx_frame_err = RxFrameErr, rx_over_err = RxOverErr,
			rx_crc_err = RxCrcErr, collisions = Collisions},
    decode_stats_reply(port, [R|Acc], Rest);

decode_stats_reply(queue, Acc, <<Port:32/integer, Queue:32/integer, TxBytes:64/integer,
				 TxPackets:64/integer, TxErrors:64/integer, Rest/binary>>) ->
    R = #ofp_queue_stats{port_no = dec_ofp_port(Port), queue_id = ofp_queue(Queue),
			 tx_bytes = TxBytes, tx_packets = TxPackets, tx_errors = TxErrors},
    decode_stats_reply(queue, [R|Acc], Rest);

decode_stats_reply(group, Acc, <<Len:16/integer, _Pad0:2/bytes, GroupId:32/integer, RefCount:32/integer,
				 _Pad1:4/bytes, PacketCount:64/integer, ByteCount:64/integer, More/binary>>) ->
    BucketStatsLen = Len - 32,
    <<BucketStats:BucketStatsLen/bytes, Rest/binary>> = More,
    R = #ofp_group_stats{group_id = GroupId, ref_count = RefCount,
			 packet_count = PacketCount, byte_count = ByteCount,
			 bucket_stats = decode_ofp_bucket_stats(BucketStats)},
    decode_stats_reply(group, [R|Acc], Rest);

decode_stats_reply(group_desc, Acc, <<Len:16/integer, Type:8/integer, _Pad:1/bytes, GroupId:32/integer, More/binary>>) ->
    BucketsLen = Len - 8,
    <<Buckets:BucketsLen/bytes, Rest/binary>> = More,
    R = #ofp_group_desc_stats{type = ofp_group_type(Type), group_id = GroupId, buckets = decode_ofp_buckets(Buckets)},
    decode_stats_reply(group_desc, [R|Acc], Rest);

decode_stats_reply(group_features, Acc, <<Types:32/integer, Capabilities:32/integer, MaxGroups:16/bytes, Actions:16/bytes, Rest/binary>>) ->
    R = #ofp_group_features{
      types = Types,
      capabilities = Capabilities,
      max_groups = [X || <<X:32/integer>> <= MaxGroups],
      actions = [X || <<X:32/integer>> <= Actions]},
    decode_stats_reply(group_desc, [R|Acc], Rest);
    
decode_stats_reply(experimenter, Acc, <<Experimenter:32/integer, Msg/binary>>) ->
    decode_experimenter_stats(experimenter(Experimenter), Acc, Msg).

decode_experimenter_stats(Experimenter, Acc, <<SubType:32/integer, _Pad:4/bytes, Msg/binary>>) ->
    decode_stats_reply(ofp_experimenter_stats_type({Experimenter, SubType}), Acc, Msg).

decode_ofp_bucket_stats(BucketStats) ->
    [#ofp_bucket_counter{packet_count = PacketCount, byte_count = ByteCount} || <<PacketCount: 64/integer, ByteCount:64/integer>> <= BucketStats].

%%%===================================================================
%%% Encode
%%%===================================================================
-spec encode_ovs_experimenter({Experimenter :: atom(), Cmd :: non_neg_integer()}, binary()) -> binary();
		       ({Experimenter :: non_neg_integer(), Cmd :: non_neg_integer()}, binary()) -> binary();
		       (Cmd :: of_experimenter_ext(), binary()) -> binary().
encode_ovs_experimenter({Experimenter, Cmd}, Data)
  when is_atom(Experimenter) ->
    encode_ovs_experimenter({experimenter(Experimenter), Cmd}, Data);
encode_ovs_experimenter({Experimenter, Cmd}, Data) ->
    <<Experimenter:32, Cmd:32, Data/binary>>;
encode_ovs_experimenter(Cmd, Data) ->
    encode_ovs_experimenter(of_experimenter_ext(Cmd), Data).

encode_phy_port(#ofp_phy_port{port_no = PortNo, hw_addr = HwAddr, name = Name,
			      config = Config, state = State, curr = Curr,
			      advertised = Advertised, supported = Supported,
			      peer = Peer, curr_speed = CurrSpeed, max_speed = MaxSpeed}) ->
    Name0 = pad_to(16, Name),
    <<(enc_ofp_port(PortNo)):32, 0:32, HwAddr:6/bytes, 0:16, Name0:16/bytes,
      (enc_flags(ofp_port_config(), Config)):32,
      (enc_flags(ofp_port_state(), State)):32,
      (enc_flags(ofp_port_features(), Curr)):32,
      (enc_flags(ofp_port_features(), Advertised)):32,
      (enc_flags(ofp_port_features(), Supported)):32,
      (enc_flags(ofp_port_features(), Peer)):32,
      CurrSpeed:32, MaxSpeed:32>>.

encode_phy_ports(Ports) ->
    << << (encode_phy_port(P))/binary >> || P <- Ports >>.

encode_ofp_queue_prop(none) ->
    <<>>;
encode_ofp_queue_prop(#ofp_queue_prop_min_rate{rate = Rate}) ->
    <<Rate:16>>;
encode_ofp_queue_prop(#ofp_queue_prop_max_rate{rate = Rate}) ->
    <<Rate:16>>.

encode_ofp_packet_queue(#ofp_packet_queue_v12{queue_id = QueueId, port = Port, properties = Properties}) ->
    Props = << << (pad_to(8, encode_ofp_queue_prop(P)))/binary >> || P <- Properties >>,
    Len = size(Props) + 8,
    <<QueueId:32, (enc_ofp_port(Port)):32, Len:16, 0:48, Props/binary>>.

-spec encode_ofp_packet_queues([#ofp_packet_queue_v12{}]) -> binary().
encode_ofp_packet_queues(Queues) ->
    << << (encode_ofp_packet_queue(Q))/binary >> || Q <- Queues >>.

encode_rofl_flowspace(Action, Match) ->
    Length = byte_size(Match) + 8,
    Bin = <<1:8, 2:8, Length:16, Action:8, 0:24, Match/binary>>,
    encode_ovs_experimenter(rofl_flowspace, Bin).

%% -spec bool(boolean()) -> 0 | 1;
%% 	  (non_neg_integer()) -> boolean().
%% bool(true) -> 1;
%% bool(false) -> 0;
%% bool(0) -> false;
%% bool(_) -> true.

%% int_maybe_undefined(X) when is_integer(X) -> X;
%% int_maybe_undefined(undefined) -> 0.

bin_maybe_undefined(X, Len) when is_binary(X) -> pad_to(Len, X);
bin_maybe_undefined(undefined, Len) -> pad_to(Len, <<0>>).

bin_fixed_length(X, Len) when size(X) > Len -> binary_part(X, {0, Len});
bin_fixed_length(X, Len) -> bin_maybe_undefined(X, Len).

-spec encode_ofs_action(int16(), binary()) -> binary().
encode_ofs_action(Type, Data) ->
    PadLen = pad_length(8, size(Data) + 4),
    Len = 4 + size(Data) + PadLen,
    <<Type:16, Len:16, Data/binary, 0:(PadLen*8)>>.

-spec encode_ofs_action_output(ofp_port(), int16()) -> binary().
encode_ofs_action_output(Port, MaxLen) ->
    Port0 = enc_ofp_port(Port),
    encode_ofs_action(?OFP12AT_OUTPUT, <<Port0:32, MaxLen:16, 0:48>>).

-spec encode_ofs_action_copy_ttl_out() -> binary().
encode_ofs_action_copy_ttl_out() ->
    encode_ofs_action(?OFP12AT_COPY_TTL_OUT, <<0:32>>).

-spec encode_ofs_action_copy_ttl_in() -> binary().
encode_ofs_action_copy_ttl_in() ->
    encode_ofs_action(?OFP12AT_COPY_TTL_IN, <<0:32>>).

-spec encode_ofs_action_set_mpls_label(int32()) -> binary().
encode_ofs_action_set_mpls_label(MplsLabel) ->
    encode_ofs_action(13, <<MplsLabel:32>>).

-spec encode_ofs_action_set_mpls_tc(int8()) -> binary().
encode_ofs_action_set_mpls_tc(MplsTc) ->
    encode_ofs_action(14, <<MplsTc:8, 0:24>>).

-spec encode_ofs_action_set_mpls_ttl(int8()) -> binary().
encode_ofs_action_set_mpls_ttl(MplsTTL) ->
    encode_ofs_action(?OFP12AT_SET_MPLS_TTL, <<MplsTTL:8, 0:24>>).

-spec encode_ofs_action_dec_mpls_ttl() -> binary().
encode_ofs_action_dec_mpls_ttl() ->
    encode_ofs_action(?OFP12AT_DEC_MPLS_TTL, <<0:32>>).

-spec encode_ofs_action_push_vlan(int16()) -> binary().
encode_ofs_action_push_vlan(EtherType) ->
    encode_ofs_action(?OFP12AT_PUSH_VLAN, <<EtherType:16, 0:16>>).

-spec encode_ofs_action_pop_vlan() -> binary().
encode_ofs_action_pop_vlan() ->
    encode_ofs_action(?OFP12AT_POP_VLAN, <<0:32>>).

-spec encode_ofs_action_push_mpls(int16()) -> binary().
encode_ofs_action_push_mpls(EtherType) ->
    encode_ofs_action(?OFP12AT_PUSH_MPLS, <<EtherType:16, 0:16>>).

-spec encode_ofs_action_pop_mpls(int16()) -> binary().
encode_ofs_action_pop_mpls(EtherType) ->
    encode_ofs_action(?OFP12AT_POP_MPLS, <<EtherType:16, 0:16>>).

-spec encode_ofs_action_set_queue(int32()) -> binary().
encode_ofs_action_set_queue(QueueId) ->
    encode_ofs_action(?OFP12AT_SET_QUEUE, <<QueueId:32>>).

-spec encode_ofs_action_group(int32()) -> binary().
encode_ofs_action_group(GroupId) ->
    encode_ofs_action(?OFP12AT_GROUP, <<GroupId:32>>).

-spec encode_ofs_action_set_nw_ttl(int8()) -> binary().
encode_ofs_action_set_nw_ttl(NwTTL) ->
    encode_ofs_action(?OFP12AT_SET_NW_TTL, <<NwTTL:8, 0:24>>).

-spec encode_ofs_action_dec_nw_ttl() -> binary().
encode_ofs_action_dec_nw_ttl() ->
    encode_ofs_action(?OFP12AT_DEC_NW_TTL, <<0:32>>).

-spec encode_ofs_action_set_field(term()) -> binary().
encode_ofs_action_set_field(TLV) ->
    encode_ofs_action(?OFP12AT_SET_FIELD, encode_oxm_tlv(TLV)).

-spec encode_ofs_action_push_capwap() -> binary().
encode_ofs_action_push_capwap() ->
    encode_ofs_action_experimenter(?TRAVELPING_EXPERIMENTER_ID, <<?OFXAT_TP_PUSH_CAPWAP:16>>).

-spec encode_ofs_action_pop_capwap() -> binary().
encode_ofs_action_pop_capwap() ->
    encode_ofs_action_experimenter(?TRAVELPING_EXPERIMENTER_ID, <<?OFXAT_TP_POP_CAPWAP:16>>).

-spec encode_ofs_action_push_ieee80211() -> binary().
encode_ofs_action_push_ieee80211() ->
    encode_ofs_action_experimenter(?TRAVELPING_EXPERIMENTER_ID, <<?OFXAT_TP_PUSH_IEEE80211:16>>).

-spec encode_ofs_action_pop_ieee80211() -> binary().
encode_ofs_action_pop_ieee80211() ->
    encode_ofs_action_experimenter(?TRAVELPING_EXPERIMENTER_ID, <<?OFXAT_TP_POP_IEEE80211:16>>).

-spec encode_ofs_action_experimenter(int32(), binary()) -> binary().
encode_ofs_action_experimenter(Experimenter, Msg) ->
    encode_ofs_action(?OFP12AT_EXPERIMENTER, <<Experimenter:32, Msg/binary>>).

encode_ofp_stats_request(Type, Flags, Body) when is_atom(Type) ->
    encode_ofp_stats_request(ofp_stats_type(Type), Flags, Body);
encode_ofp_stats_request(Type, Flags, Body) when is_integer(Type) ->
    <<Type:16, Flags:16, 0:32, Body/binary>>.

%% TODO: we don't support flags in stats replies...
encode_ofp_stats({experimenter, Type}, Body) ->
    encode_ofp_experimenter_stats(Type, Body);
encode_ofp_stats(Type, Body) when is_atom(Type) ->
    encode_ofp_stats(ofp_stats_type(Type), Body);
encode_ofp_stats(Type, Body) when is_integer(Type) ->
    <<Type:16, 0:16, 0:32, Body/binary>>.

encode_ofp_experimenter_stats(Type, Body) when is_atom(Type) ->
    encode_ofp_experimenter_stats(ofp_experimenter_stats_type(Type), Body).

encode_action(#ofp_action_output{port = Port, max_len = MaxLen}) ->
    encode_ofs_action_output(Port, MaxLen);

encode_action(#ofp_action_copy_ttl_out{}) ->
    encode_ofs_action_copy_ttl_out();

encode_action(#ofp_action_copy_ttl_in{}) ->
    encode_ofs_action_copy_ttl_in();

encode_action(#ofp_action_set_mpls_label{label = MplsLabel}) ->
    encode_ofs_action_set_mpls_label(MplsLabel);

encode_action(#ofp_action_set_mpls_tc{tc = MplsTc}) ->
    encode_ofs_action_set_mpls_tc(MplsTc);

encode_action(#ofp_action_set_mpls_ttl{ttl = MplsTtl}) ->
    encode_ofs_action_set_mpls_ttl(MplsTtl);

encode_action(#ofp_action_dec_mpls_ttl{}) ->
    encode_ofs_action_dec_mpls_ttl();

encode_action(#ofp_action_push_vlan{ethertype = EtherType}) ->
    encode_ofs_action_push_vlan(EtherType);

encode_action(#ofp_action_pop_vlan{}) ->
    encode_ofs_action_pop_vlan();

encode_action(#ofp_action_push_mpls{ethertype = EtherType}) ->
    encode_ofs_action_push_mpls(EtherType);

encode_action(#ofp_action_pop_mpls{ethertype = EtherType}) ->
    encode_ofs_action_pop_mpls(EtherType);

encode_action(#ofp_action_set_queue{queue_id = QueueId}) ->
    encode_ofs_action_set_queue(QueueId);

encode_action(#ofp_action_group{group_id = GroupId}) ->
    encode_ofs_action_group(GroupId);

encode_action(#ofp_action_set_nw_ttl{ttl = TTL}) ->
    encode_ofs_action_set_nw_ttl(TTL);

encode_action(#ofp_action_dec_nw_ttl{}) ->
    encode_ofs_action_dec_nw_ttl();

encode_action(#ofp_action_set_field{tlv = TLV}) ->
    encode_ofs_action_set_field(TLV);

encode_action(#ofp_action_push_capwap{}) ->
    encode_ofs_action_push_capwap();

encode_action(#ofp_action_pop_capwap{}) ->
    encode_ofs_action_pop_capwap();

encode_action(#ofp_action_push_ieee80211{}) ->
    encode_ofs_action_push_ieee80211();

encode_action(#ofp_action_pop_ieee80211{}) ->
    encode_ofs_action_pop_ieee80211();

encode_action(#ofp_action_experimenter{experimenter = Experimenter, msg = Msg}) ->
    encode_ofs_action_experimenter(Experimenter, Msg);

encode_action(Action) when is_binary(Action) ->
    pad_to(8, Action).

encode_actions(List) when is_list(List) ->
    iolist_to_binary([encode_action(A) || A <- List]);
encode_actions(Action) when is_tuple(Action) ->
    encode_action(Action).

%% Instructions
encode_instruction(Type, Instruction) ->
    <<(ofp_instruction_type(Type)):16, (size(Instruction) + 4):16, Instruction/binary>>.

encode_instruction_goto_table(TableId) ->
    encode_instruction(goto_table, <<TableId:8, 0:24>>).
encode_instruction_write_metadata(MetaData, MetaDataMask) ->
    encode_instruction(write_metadata, <<0:32, MetaData:64, MetaDataMask:64>>).
encode_instruction_actions(Type, Actions) ->
    encode_instruction(Type, <<0:32, (encode_actions(Actions))/binary>>).
    

encode_instruction(#ofp_instruction_goto_table{table_id = TableId}) ->
    encode_instruction_goto_table(TableId);
encode_instruction(#ofp_instruction_write_metadata{metadata = MetaData, metadata_mask = MetaDataMask}) ->
    encode_instruction_write_metadata(MetaData, MetaDataMask);
encode_instruction(#ofp_instruction_actions{type = Type, actions = Actions}) ->
    encode_instruction_actions(Type, Actions);

encode_instruction(Instruction) when is_binary(Instruction) ->
    pad_to(8, Instruction).

encode_instructions(List) when is_list(List) ->
    iolist_to_binary([encode_instruction(A) || A <- List]);
encode_instructions(Instruction) when is_tuple(Instruction) ->
    encode_instruction(Instruction).

%% Buckets
encode_bucket(#ofp_bucket{weight = Weight, watch_port = WatchPort,
			  watch_group = WatchGroup, actions = Actions}) ->
    Actions0 = encode_actions(Actions),
    Len = 16 + size(Actions0),
    <<Len:16, Weight:16, (enc_ofp_port(WatchPort)):32, WatchGroup:32, 0:32, Actions0/binary>>.

encode_buckets(List) when is_list(List) ->
    iolist_to_binary([encode_bucket(A) || A <- List]);
encode_buckets(Bucket) when is_tuple(Bucket) ->
    encode_bucket(Bucket).

%% Stats Reques/Reply

encode_stats_reply_entry(#ofp_desc_stats{mfr_desc = MfrDesc, hw_desc = HwDesc, sw_desc = SwDesc,
					 serial_num = SerialNum, dp_desc = DpDesc}) ->
    <<(bin_fixed_length(MfrDesc, 256)):256/bytes,
      (bin_fixed_length(HwDesc, 256)):256/bytes,
      (bin_fixed_length(SwDesc, 256)):256/bytes,
      (bin_fixed_length(SerialNum, 32)):32/bytes,
      (bin_fixed_length(DpDesc, 256)):256/bytes>>;

encode_stats_reply_entry(#ofp_flow_stats_v11{table_id = TableId, duration = {Sec, NSec}, priority = Priority,
					     idle_timeout = IdleTimeout, hard_timeout = HardTimeout, cookie = Cookie,
					     packet_count = PacketCount, byte_count = ByteCount, match = Match, instructions = Instructions}) ->
    BinMatch = encode_ofp_match(Match),
    BinInstr = encode_instructions(Instructions),
    Length = 48 + size(Match) + size(Instructions),
    <<Length:16, TableId:8, 0:8, Sec:32, NSec:32, Priority:16, IdleTimeout:16, HardTimeout:16, 0:48,
      Cookie:64, PacketCount:64, ByteCount:64, BinMatch/binary, BinInstr/binary>>;

encode_stats_reply_entry(#ofp_aggregate_stats{packet_count = PacketCount, byte_count = ByteCount, flow_count = FlowCount}) ->
    <<PacketCount:64, ByteCount:64, FlowCount:32, 0:32>>;

encode_stats_reply_entry(#ofp_table_stats_v12{table_id = TableId, name = Name, 
					      match = Match, wildcards = Wildcards,
					      write_actions = WriteActions, apply_actions = ApplyActions,
					      write_setfields = WriteSetFields, apply_setfields = ApplySetFields,
					      metadata_match = MetadataMatch, metadata_write = MetadataWrite,
					      instructions = Instructions,
					      config = Config, max_entries = MaxEntries, active_count = ActiveCount,
					      lookup_count = LookupCount, matched_count = MatchedCount}) ->
    <<TableId:8, 0:56,
      (bin_fixed_length(Name, 32))/binary,
      (enc_flags(ofp_xmt_type(), Match)):64,
      (enc_flags(ofp_xmt_type(), Wildcards)):64,
      (enc_flags(ofp_action_type(), WriteActions)):32,
      (enc_flags(ofp_action_type(), ApplyActions)):32,
      (enc_flags(ofp_xmt_type(), WriteSetFields)):64,
      (enc_flags(ofp_xmt_type(), ApplySetFields)):64,
      MetadataMatch:64, MetadataWrite:64,
      (enc_flags(ofp_instruction_types(), Instructions)):32,
      Config:32, MaxEntries:32, ActiveCount:32,
      LookupCount:64, MatchedCount:64>>;

encode_stats_reply_entry(#ofp_port_stats{port_no = Port, rx_packets = RxPackets, tx_packets = TxPackets, rx_bytes = RxBytes, tx_bytes = TxBytes,
					 rx_dropped = RxDropped, tx_dropped = TxDropped, rx_errors = RxErrors, tx_errors = TxErrors,
					 rx_frame_err = RxFrameErr, rx_over_err = RxOverErr, rx_crc_err = RxCrcErr, collisions = Collisions}) ->
    <<Port:32, 0:32, RxPackets:64, TxPackets:64, RxBytes:64, TxBytes:64, RxDropped:64, TxDropped:64,
      RxErrors:64, TxErrors:64, RxFrameErr:64, RxOverErr:64, RxCrcErr:64, Collisions:64>>;

encode_stats_reply_entry(#ofp_queue_stats{port_no = Port, queue_id = Queue, tx_bytes = TxBytes, tx_packets = TxPackets, tx_errors = TxErrors}) ->
    <<Port:32, Queue:32, TxBytes:64, TxPackets:64, TxErrors:64>>;

encode_stats_reply_entry(#ofp_group_stats{group_id = GroupId, ref_count = RefCount,
					  packet_count = PacketCount, byte_count = ByteCount,
					  bucket_stats = BucketStats}) ->
    BinBucketStats = encode_bucket_stats(BucketStats),
    Len = 32 + size(BinBucketStats),
    <<Len:16, 0:16, GroupId:32, RefCount:32, 0:32, PacketCount: 64, ByteCount:64, BinBucketStats/binary>>;

encode_stats_reply_entry(#ofp_group_desc_stats{type = Type, group_id = GroupId, buckets = Buckets}) ->
    BinBuckets = encode_bucket(Buckets),
    Len = 8 + size(Buckets),
    <<Len:16, (ofp_group_type(Type)):8, 0:8, GroupId:32, BinBuckets/binary>>;

encode_stats_reply_entry(#ofp_group_features{types = Types, capabilities = Capabilities,
					     max_groups = MaxGroups,
					     actions = Actions})
  when length(MaxGroups) =< 4,
       length(Actions) =< 4 ->
    BinMaxGroups = << <<X:32>> || X <- MaxGroups>>,
    BinActions = << <<X:32>> || X <- Actions>>,
    <<Types:32, Capabilities:32, (pad_to(16, BinMaxGroups))/binary, (pad_to(16, BinActions))/binary>>.

encode_bucket_counter(#ofp_bucket_counter{packet_count = PacketCount,
					  byte_count = ByteCount}) ->
    <<PacketCount: 64, ByteCount:64>>.

encode_bucket_stats(BucketStats) when is_binary(BucketStats) ->
    BucketStats;
encode_bucket_stats(BucketStats) when is_tuple(BucketStats) ->
    encode_bucket_counter(BucketStats);
encode_bucket_stats(BucketStats) when is_list(BucketStats) ->
    << <<(encode_bucket_counter(B))/binary>> || B <- BucketStats>>.

stats_reply_record_type(ofp_desc_stats)			-> desc;
stats_reply_record_type(ofp_flow_stats_v11)		-> flow;
stats_reply_record_type(ofp_aggregate_stats)		-> aggregate;
stats_reply_record_type(ofp_table_stats_v12)		-> table;
stats_reply_record_type(ofp_rofl_broken_table_stats_v12)-> table;
stats_reply_record_type(ofp_port_stats)			-> port;
stats_reply_record_type(ofp_queue_stats)		-> queue.

encode_stats_reply([], _RecType, Acc) ->
    list_to_binary(lists:reverse(Acc));
encode_stats_reply([Head|Rest], RecType, Acc) ->
    case is_record(Head, RecType) of
	true ->
	    encode_stats_reply(Rest, RecType, [encode_stats_reply_entry(Head)|Acc]);
	_ ->
	    error(badarg, [Head])
    end.

encode_stats_reply(Reply, RecType) ->
    Body = encode_stats_reply(Reply, RecType, []),
    Type = stats_reply_record_type(RecType),
    encode_ofp_stats(Type, Body).

encode_ofp_match(Match) ->
    Fields = << << (encode_oxm_tlv(TLV))/binary >> || TLV <- Match >>,
    Length = byte_size(Fields) + 4,
    pad_to(8, <<1:16, Length:16, Fields/binary>>).

-define(ENCODE_OXM_TLV(Class, Field, Length, Type, Atom),
	encode_oxm_tlv({Atom, Value}) ->
	       <<Class:16/integer, Field:7/integer, 0:1, (Length div 8):8/integer, Value:Length/Type>>).

-define(ENCODE_OXM_TLV_MAP(Class, Field, Length, Type, Atom, MAP),
	encode_oxm_tlv({Atom, Value}) ->
	       <<Class:16/integer, Field:7/integer, 0:1, (Length div 8):8/integer, (MAP(Value)):Length/Type>>).

-define(ENCODE_OXM_MASK_TLV(Class, Field, Length, Type, Atom),
	encode_oxm_tlv({Atom, Value, Mask}) ->
	       <<Class:16/integer, Field:7/integer, 1:1, (Length div 4):8/integer,
		 Value:Length/Type, Mask:Length/Type>>).

?ENCODE_OXM_TLV_MAP(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IN_PORT, 32, integer, in_port, enc_ofp_port);
?ENCODE_OXM_TLV_MAP(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IN_PHY_PORT, 32, integer, in_phy_port, enc_ofp_port);
?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_METADATA, 64, bits, metadata);
?ENCODE_OXM_MASK_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_METADATA, 64, bits, metadata);
?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ETH_DST, 48, bits, eth_dst);
?ENCODE_OXM_MASK_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ETH_DST, 48, bits, eth_dst);
?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ETH_SRC, 48, bits, eth_src);
?ENCODE_OXM_MASK_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ETH_SRC, 48, bits, eth_src);
?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ETH_TYPE, 16, integer, eth_type);

encode_oxm_tlv({vlan_vid, none}) ->
    <<?OFPXMC_OPENFLOW_BASIC:16, ?OFPXMT_OFB_VLAN_VID:7, 0:1, 2:8, 16#0000:2>>;

encode_oxm_tlv({vlan_vid, present}) ->
    <<?OFPXMC_OPENFLOW_BASIC:16, ?OFPXMT_OFB_VLAN_VID:7, 1:1, 4:8, 16#1000:2, 16#1000:2>>;

encode_oxm_tlv({vlan_vid, Value}) ->
    <<?OFPXMC_OPENFLOW_BASIC:16, ?OFPXMT_OFB_VLAN_VID:7, 0:1, 2:8, Value:2>>;

?ENCODE_OXM_MASK_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_VLAN_VID, 2, bits, vlan_vid);

encode_oxm_tlv({vlan_pcp, Value}) ->
    <<?OFPXMC_OPENFLOW_BASIC:16, ?OFPXMT_OFB_VLAN_PCP:7, 0:1, 1:8, 0:5, Value:3>>;

encode_oxm_tlv({ip_dscp, Value}) ->
    <<?OFPXMC_OPENFLOW_BASIC:16, ?OFPXMT_OFB_IP_DSCP:7, 0:1, 1:8, 0:2, Value:6>>;

encode_oxm_tlv({ip_ecn, Value}) ->
    <<?OFPXMC_OPENFLOW_BASIC:16, ?OFPXMT_OFB_IP_ECN:7, 0:1, 1:8, 0:6, Value:2>>;

?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IP_PROTO, 8, integer, ip_proto);
?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IPV4_SRC, 32, bits, ipv4_src);
?ENCODE_OXM_MASK_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IPV4_SRC, 32, bits, ipv4_src);
?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IPV4_DST, 32, bits, ipv4_dst);
?ENCODE_OXM_MASK_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IPV4_DST, 32, bits, ipv4_dst);
?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_TCP_SRC, 16, integer, tcp_src);
?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_TCP_DST, 16, integer, tcp_dst);
?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_UDP_SRC, 16, integer, udp_src);
?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_UDP_DST, 16, integer, udp_dst);
?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_SCTP_SRC, 16, integer, sctp_src);
?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_SCTP_DST, 16, integer, sctp_dst);
?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ICMPV4_TYPE, 8, integer, icmpv4_type);
?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ICMPV4_CODE, 8, integer, icmpv4_code);
?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ARP_OP, 16, integer, arp_op);
?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ARP_SPA, 32, bits, arp_spa);
?ENCODE_OXM_MASK_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ARP_SPA, 32, bits, arp_spa);
?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ARP_TPA, 32, bits, arp_tpa);
?ENCODE_OXM_MASK_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ARP_TPA, 32, bits, arp_tpa);
?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ARP_SHA, 48, bits, arp_sha);
?ENCODE_OXM_MASK_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ARP_SHA, 48, bits, arp_sha);
?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ARP_THA, 48, bits, arp_tha);
?ENCODE_OXM_MASK_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ARP_THA, 48, bits, arp_tha);
?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IPV6_SRC, 128, bits, ipv6_src);
?ENCODE_OXM_MASK_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IPV6_SRC, 128, bits, ipv6_src);
?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IPV6_DST, 128, bits, ipv6_dst);
?ENCODE_OXM_MASK_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IPV6_DST, 128, bits, ipv6_dst);

encode_oxm_tlv({ipv6_flabel, Value, Mask}) ->
    <<?OFPXMC_OPENFLOW_BASIC:16, ?OFPXMT_OFB_IPV6_FLABEL:7, 1:1, 8:8, 0:4, Value:20, 0:4, Mask:20>>;

?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ICMPV6_TYPE, 8, integer, icmpv6_type);
?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_ICMPV6_CODE, 8, integer, icmpv6_code);
?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IPV6_ND_TARGET, 128, bits, ipv6_nd_target);
?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IPV6_ND_SLL, 48, bits, ipv6_nd_sll);
?ENCODE_OXM_TLV(?OFPXMC_OPENFLOW_BASIC, ?OFPXMT_OFB_IPV6_ND_TLL, 48, bits, ipv6_nd_tll);

encode_oxm_tlv({mpls_flabel, Value}) ->
    <<?OFPXMC_OPENFLOW_BASIC:16, ?OFPXMT_OFB_MPLS_LABEL:7, 1:1, 4:8, 0:4, Value:20>>;

encode_oxm_tlv({mpls_tc, Value}) ->
    <<?OFPXMC_OPENFLOW_BASIC:16, ?OFPXMT_OFB_MPLS_TC:7, 1:1, 1:8, 0:5, Value:3>>;

?ENCODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_PPPOE_CODE, 8, integer, pppoe_code);
?ENCODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_PPPOE_TYPE, 8, integer, pppoe_type);
?ENCODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_PPPOE_SID, 16, integer, pppoe_sid);
?ENCODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_PPP_PROT, 16, integer, ppp_prot);

?ENCODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_GTP_MSG_TYPE, 8, integer, gtp_msg_type);
?ENCODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_GTP_TEID, 32, bits, gtp_teid);
?ENCODE_OXM_MASK_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_GTP_TEID, 32, bits, gtp_teid);

?ENCODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_CAPWAP_WBID, 8, integer, capwap_wbid);
?ENCODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_CAPWAP_RID, 8, integer, capwap_rid);
?ENCODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_CAPWAP_FLAGS, 8, integer, capwap_flags);
?ENCODE_OXM_MASK_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_CAPWAP_FLAGS, 16, integer, capwap_flags);

?ENCODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_IEEE80211_FC, 16, integer, ieee80211_fc);
?ENCODE_OXM_MASK_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_IEEE80211_FC, 16, integer, ieee80211_fc);
?ENCODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_IEEE80211_TYPE, 8, integer, ieee80211_type);
?ENCODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_IEEE80211_SUBTYPE, 8, integer, ieee80211_subtype);
?ENCODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_IEEE80211_DIRECTION, 8, integer, ieee80211_direction);
?ENCODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_IEEE80211_ADDRESS_1, 48, bits, ieee80211_address_1);
?ENCODE_OXM_MASK_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_IEEE80211_ADDRESS_1, 48, bits, ieee80211_address_1);
?ENCODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_IEEE80211_ADDRESS_2, 48, bits, ieee80211_address_2);
?ENCODE_OXM_MASK_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_IEEE80211_ADDRESS_2, 48, bits, ieee80211_address_2);
?ENCODE_OXM_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_IEEE80211_ADDRESS_3, 48, bits, ieee80211_address_3);
?ENCODE_OXM_MASK_TLV(?OFPXMC_EXPERIMENTER, ?OFPXMT_OFX_IEEE80211_ADDRESS_3, 48, bits, ieee80211_address_3);

encode_oxm_tlv({{Class, Field}, {Value, Mask}}) ->
    Length = size(Value) + size(Mask),
    <<Class:16, Field:7, 1:1, Length:8, Value/binary, Mask/binary>>;

encode_oxm_tlv({{Class, Field}, Value})
  when is_binary(Value)  ->
    Length = size(Value),
    <<Class:16, Field:7, 0:1, Length:8, Value/binary>>.

encode_msg(#ofp_error{error = {Type, Code}, data = Data}) ->
    <<(ofp_error_type(Type)):16/integer,
      (ofp_error_code_type(Type, Code)):16/integer, Data/binary>>;

encode_msg(#ofp_switch_features{datapath_id = DataPathId,
				n_buffers = NBuffers,
				n_tables = NTables,
				capabilities = Capabilities,
				ports = Ports}) ->

    <<DataPathId:64, NBuffers:32, NTables:8, 0:24,
      (enc_flags(ofp_capabilities(), Capabilities)):32,
      0:32, (encode_phy_ports(Ports))/binary>>;

encode_msg(#ofp_switch_config{flags = Flags, miss_send_len = MissSendLen}) ->
    <<(ofp_config_flags(Flags)):16, MissSendLen:16>>;

encode_msg(#ofp_packet_in_v12{buffer_id = BufferId, total_len = TotalLen, reason = Reason,
			      table_id = TableId, match = Match, data = Data}) ->
    <<BufferId:32, TotalLen:16,
      (ofp_packet_in_reason(Reason)):8,
      TableId:8, (pad_to(8, encode_ofp_match(Match)))/binary, 0:16, Data/binary>>;

encode_msg(#ofp_flow_removed_v12{cookie = Cookie, priority = Priority, reason = Reason,
				 table_id = TableId, duration = {DurationSec, DurationNSec},
				 idle_timeout = IdleTimeout, hard_timeout = HardTimeout,
				 packet_count = PacketCount, byte_count = ByteCount, match = Match}) ->
    <<Cookie:64, Priority:16,
      (ofp_flow_removed_reason(Reason)):8,
      TableId:8, DurationSec:32, DurationNSec:32,
      IdleTimeout:16, HardTimeout:16,
      PacketCount:64, ByteCount:64,
      (encode_ofp_match(Match))/binary>>;

encode_msg(#ofp_port_status{reason = Reason, port = Port}) ->
    Reason0 = ofp_port_reason(Reason),
    <<Reason0:8, 0:56, (encode_phy_port(Port))/binary>>;

encode_msg(#ofp_packet_out{buffer_id = BufferId, in_port = InPort, actions = Actions, data = Data}) ->
    BinActions = encode_actions(Actions),
    <<BufferId:32,
      (enc_ofp_port(InPort)):32,
      (size(BinActions)):16, 0:48,
      BinActions/binary, Data/binary>>;

encode_msg(#ofp_flow_mod_v12{cookie = Cookie, cookie_mask = CookieMask, table_id = TableId,
			     command = Command, idle_timeout = IdleTimeout, hard_timeout = HardTimeout,
			     priority = Priority, buffer_id = BufferId,
			     out_port = OutPort, out_group = OutGroup,
			     flags = Flags, match = Match, instructions = Instructions}) ->
    <<Cookie:64, CookieMask:64, TableId:8,
      (ofp_flow_mod_command(Command)):8,
      IdleTimeout:16, HardTimeout:16,
      Priority:16, BufferId:32,
      (enc_ofp_port(OutPort)):32,
      (ofp_group(OutGroup)):32,
      (enc_flags(ofp_flow_mod_flags(), Flags)):16, 0:16,
      (encode_ofp_match(Match))/binary,
      (encode_instructions(Instructions))/binary>>;

encode_msg(#ofp_group_mod{command = Command, type = Type,
			  group_id = GroupId, buckets = Buckets}) ->
    BinBuckets = list_to_binary(encode_buckets(Buckets)),
    <<(ofp_group_mod_command(Command)):16,
      (ofp_group_type(Type)):8,
      0:8, GroupId:32, BinBuckets/binary>>;

encode_msg(#ofp_port_mod{port_no = PortNo, hw_addr = HwAddr,
			 config = Config, mask = Mask, advertise = Advertise}) ->
    <<PortNo:32, 0:32, HwAddr/binary, 0:16,
      (enc_flags(ofp_port_config(), Config)):32,
      (enc_flags(ofp_port_config(), Mask)):32,
      (enc_flags(ofp_port_features(), Advertise)):32>>;


encode_msg(#ofp_table_mod{table_id = TableId, config = Config}) ->
    <<TableId:8, 0:24, (enc_flags(ofp_table_config(), Config)):32>>;

encode_msg(#ofp_queue_get_config_request{port = Port}) ->
    <<(enc_ofp_port(Port)):32>>;

encode_msg(#ofp_queue_get_config_reply{port = Port, queues = Queues}) ->
    <<(enc_ofp_port(Port)):32, 0:32,
      (encode_ofp_packet_queues(Queues))/binary>>;

encode_msg([Head|_] = Msg)
  when is_record(Head, ofp_desc_stats); is_record(Head, ofp_flow_stats_v11); is_record(Head, ofp_aggregate_stats);
       is_record(Head, ofp_table_stats_v12); is_record(Head, ofp_port_stats); is_record(Head, ofp_queue_stats);
       is_record(Head, ofp_group_stats); is_record(Head, ofp_group_desc_stats); is_record(Head, ofp_group_features);
        is_record(Head, ofp_rofl_broken_table_stats_v12) ->
    encode_stats_reply(Msg, element(1, Head));

encode_msg(#ofp_desc_stats_request{}) ->
    encode_ofp_stats_request(desc, 0, <<>>);

encode_msg(#ofp_flow_stats_request_v11{table_id = TableId, out_port = OutPort, out_group = OutGroup,
				       cookie = Cookie, cookie_mask = CookieMask, match = Match}) ->

    Req = <<(ofp_table(TableId)):8, 0:24, (enc_ofp_port(OutPort)):32,
	    (ofp_group(OutGroup)):32, 0:32, Cookie:64, CookieMask:64, 
	    (encode_ofp_match(Match))/binary>>,
    encode_ofp_stats_request(flow, 0, Req);

encode_msg(#ofp_aggregate_stats_request_v11{table_id = TableId, out_port = OutPort, out_group = OutGroup,
					    cookie = Cookie, cookie_mask = CookieMask, match = Match}) ->
    Req = <<(ofp_table(TableId)):8, 0:24, (enc_ofp_port(OutPort)):32,
	    (ofp_group(OutGroup)):32, 0:32, Cookie:64, CookieMask:64,
	    (encode_ofp_match(Match))/binary>>,
    encode_ofp_stats_request(aggregate, 0, Req);

encode_msg(#ofp_table_stats_request{}) ->
    encode_ofp_stats_request(table, 0, <<>>);

encode_msg(#ofp_rofl_broken_table_stats_request{}) ->
    encode_ofp_stats_request(table, 0, binary:copy(<<0:8>>, 1024));

encode_msg(#ofp_port_stats_request{port_no = Port}) ->
    Req = <<(enc_ofp_port(Port)):32, 0:32>>,
    encode_ofp_stats_request(port, 0, Req);

encode_msg(#ofp_queue_stats_request{port_no = Port, queue_id = Queue}) ->
    Req = <<(enc_ofp_port(Port)):32, (ofp_queue(Queue)):32>>,
    encode_ofp_stats_request(queue, 0, Req);

encode_msg(#ofp_group_stats_request{group_id = GroupId}) ->
    Req = <<GroupId:32, 0:32>>,
    encode_ofp_stats_request(group, 0, Req);

encode_msg(#ofp_group_desc_stats_request{}) ->
    encode_ofp_stats_request(group_desc, 0, <<>>);

encode_msg(#ofp_group_features_request{}) ->
    encode_ofp_stats_request(group_features, 0, <<>>);

%%---------------------------
%% Experimenter Extensions
%%---------------------------
encode_msg(#rofl_flowspace{action = add, match = Match}) ->
    encode_rofl_flowspace(1, encode_ofp_match(Match));
encode_msg(#rofl_flowspace{action = del, match = Match}) ->
    encode_rofl_flowspace(2, encode_ofp_match(Match));

encode_msg(Msg)
  when is_binary(Msg) ->
    Msg.

%%%===================================================================
%%% Internal functions
%%%===================================================================

pad_length(Width, Length) ->
    (Width - Length rem Width) rem Width.

%%
%% pad binary to specific length
%%   -> http://www.erlang.org/pipermail/erlang-questions/2008-December/040709.html
%%
pad_to(Width, Binary) ->
    case pad_length(Width, size(Binary)) of
	0 -> Binary;
	N -> <<Binary/binary, 0:(N*8)>>
    end.

%%FIXME: bitstring comprehension could be (much) simpler....
dec_flag([], _, Acc) ->
    Acc;
dec_flag([Flag|Rest], F, Acc) ->
    case F rem 2 of
        1 -> dec_flag(Rest, F bsr 1, [Flag | Acc]);
        _ -> dec_flag(Rest, F bsr 1, Acc)
    end.

-spec dec_flags(Flags, non_neg_integer()) -> Flags.
dec_flags(Map, Flag) ->
    dec_flag(Map, Flag, []).

enc_flag([], _, _, Acc) ->
    Acc;
enc_flag([Flag|Rest], F, Pos, Acc) ->
    case proplists:get_bool(Flag, F) of
	true -> enc_flag(Rest, F, Pos bsl 1, Acc bor Pos);
	_    -> enc_flag(Rest, F, Pos bsl 1, Acc)
    end.

-spec enc_flags([Flags :: atom()], [Flags :: atom()]) -> non_neg_integer().
enc_flags(Map, Flag) ->
    enc_flag(Map, Flag, 1, 0).
