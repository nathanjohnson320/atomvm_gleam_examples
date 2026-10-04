-module(wifi_ffi).
-export([connect/2]).

%% wait_for_sta/2 returns once the badge has associated and DHCP has given it
%% an address, or with an error when neither happens in time.
connect(Ssid, Psk) ->
    Config = [
        {ssid, Ssid},
        {psk, Psk},
        {dhcp_hostname, <<"avm-badge">>}
    ],
    case network:wait_for_sta(Config, 30_000) of
        {ok, {Address, _Netmask, _Gateway}} ->
            {ok, format(Address)};
        {error, timeout} ->
            {error, timeout};
        {error, disconnected} ->
            {error, disconnected};
        {error, Reason} when is_atom(Reason) ->
            {error, {other, atom_to_binary(Reason, utf8)}};
        {error, Reason} ->
            {error, {other, iolist_to_binary(io_lib:format("~p", [Reason]))}}
    end.

format({A, B, C, D}) ->
    iolist_to_binary(
        io_lib:format("~p.~p.~p.~p", [A, B, C, D])
    ).
