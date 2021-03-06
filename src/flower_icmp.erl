-module(flower_icmp).

%% API
-export([make_icmp/7, make_icmp/9, op/1]).

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("flower_packet.hrl").
-include("flower_flow.hrl").

%%--------------------------------------------------------------------
%% @doc
%% Make an ethernet ICMP packet
%%
%% @end
%%--------------------------------------------------------------------

op(echoreply)				-> {0, 0};
op(source_quench)			-> {4, 0};
op(echo)				-> {8, 0};
op(parameterprob)			-> {12, 0};
op(timestamp)				-> {13, 0};
op(timestampreply)			-> {14, 0};
op(info_request)			-> {15, 0};
op(info_reply)				-> {16, 0};
op(address)				-> {17, 0};
op(addressreply)			-> {18, 0};
op({dest_unreach, net_unreach})		-> {3, 0};
op({dest_unreach, host_unreach})	-> {3, 1};
op({dest_unreach, prot_unreach})	-> {3, 2};
op({dest_unreach, port_unreach})	-> {3, 3};
op({dest_unreach, frag_needed})		-> {3, 4};
op({dest_unreach, sr_failed})		-> {3, 5};
op({dest_unreach, net_unknown})		-> {3, 6};
op({dest_unreach, host_unknown})	-> {3, 7};
op({dest_unreach, host_isolated})	-> {3, 8};
op({dest_unreach, net_ano})		-> {3, 9};
op({dest_unreach, host_ano})		-> {3, 10};
op({dest_unreach, net_unr_tos})		-> {3, 11};
op({dest_unreach, host_unr_tos})	-> {3, 12};
op({dest_unreach, pkt_filtered})	-> {3, 13};
op({dest_unreach, prec_violation})	-> {3, 14};
op({dest_unreach, prec_cutoff})		-> {3, 15};
op({redirect, redir_net})		-> {5, 0};
op({redirect, redir_host})		-> {5, 1};
op({redirect, redir_nettos})		-> {5, 2};
op({redirect, redir_hosttos})		-> {5, 3};
op({time_exceeded, exc_ttl})		-> {11, 0};
op({time_exceeded, exc_fragtime})	-> {11, 1};

op({0, 0})	-> echoreply;
op({3, 0})	-> {dest_unreach, net_unreach};
op({3, 1})	-> {dest_unreach, host_unreach};
op({3, 2})	-> {dest_unreach, prot_unreach};
op({3, 3})	-> {dest_unreach, port_unreach};
op({3, 4})	-> {dest_unreach, frag_needed};
op({3, 5})	-> {dest_unreach, sr_failed};
op({3, 6})	-> {dest_unreach, net_unknown};
op({3, 7})	-> {dest_unreach, host_unknown};
op({3, 8})	-> {dest_unreach, host_isolated};
op({3, 9})	-> {dest_unreach, net_ano};
op({3, 10})	-> {dest_unreach, host_ano};
op({3, 11})	-> {dest_unreach, net_unr_tos};
op({3, 12})	-> {dest_unreach, host_unr_tos};
op({3, 13})	-> {dest_unreach, pkt_filtered};
op({3, 14})	-> {dest_unreach, prec_violation};
op({3, 15})	-> {dest_unreach, prec_cutoff};
op({4, 0})	-> source_quench;
op({5, 0})	-> {redirect, redir_net};
op({5, 1})	-> {redirect, redir_host};
op({5, 2})	-> {redirect, redir_nettos};
op({5, 3})	-> {redirect, redir_hosttos};
op({8, 0})	-> echo;
op({11, 0})	-> {time_exceeded, exc_ttl};
op({11, 1})	-> {time_exceeded, exc_fragtime};
op({12, 0})	-> parameterprob;
op({13, 0})	-> timestamp;
op({14, 0})	-> timestampreply;
op({15, 0})	-> info_request;
op({16, 0})	-> info_reply;
op({17, 0})	-> address;
op({18, 0})	-> addressreply.

make_icmp(Op, TCI, DlDst, DlSrc, NwSrc, NwDst, IPHdr) ->
    make_icmp(Op, TCI, DlDst, DlSrc, NwSrc, NwDst, IPHdr, 0, 0).

%% NB: In an echo-reply, the 'IcmpId' and 'IcmpSeqNo' should be
%% the same as in the matching icmp-request (actually the rest
%% of the data should be preserved too 'IPHdr').
%% In those cases where we want to send an ICMP error message,
%% the IPHdr should be the original IP packet header.
make_icmp(Op, TCI, DlDst, DlSrc, NwSrc, NwDst, IPHdr, IcmpId, IcmpSeqNo) ->
    {Type, Code} = op(Op),
    Ether = flower_tools:ether_hdr(DlDst, DlSrc, TCI, flower_packet:eth_type(ip)),

    ICMPCSum = flower_tools:ip_csum(<<Type:8, Code:8, 0:16, IcmpId:16, IcmpSeqNo:16, IPHdr/binary>>),
    ICMP = <<Type:8, Code:8, ICMPCSum:16, IcmpId:16, IcmpSeqNo:16, IPHdr/binary>>,

    TotLen = 20 + size(ICMP),
    Id = 0,
    Proto = gen_socket:protocol(icmp),
    HdrCSum = flower_tools:ip_csum(<<4:4, 5:4, 0:8, TotLen:16,
				     Id:16, 0:16, 64:8, Proto:8,
				     0:16/integer, NwSrc:4/bytes-unit:8, NwDst:4/bytes-unit:8>>),
    IP = <<4:4, 5:4, 0:8, TotLen:16,
	   Id:16, 0:16, 64:8, Proto:8,
	   HdrCSum:16/integer, NwSrc:4/bytes-unit:8, NwDst:4/bytes-unit:8>>,
    list_to_binary([Ether, IP, ICMP]).
