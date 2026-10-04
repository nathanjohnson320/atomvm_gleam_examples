-module(mqtt_ffi).
-export([connect/3, publish/3]).

%% connect/1 returns as soon as the CONNECT packet is on its way. The broker
%% accepting it arrives later as `{mqtt, Client, connack, Info}`.
%%
%% Host is a Gleam string (binary); AtomVM's gen_tcp resolves charlists.
connect(Host, Port, ClientId) ->
    HostCharlist = unicode:characters_to_list(Host),
    case amqtt_client:connect(#{
        host => HostCharlist,
        port => Port,
        client_id => ClientId
    }) of
        {ok, Client} ->
            receive
                {mqtt, Client, connack, _Info} ->
                    {ok, Client}
            after
                15_000 ->
                    {error, timeout}
            end;
        {error, Reason} when is_atom(Reason) ->
            {error, {other, atom_to_binary(Reason, utf8)}};
        {error, Reason} ->
            {error, {other, iolist_to_binary(io_lib:format("~p", [Reason]))}};
        error ->
            {error, failed}
    end.

publish(Client, Topic, Payload) ->
    case amqtt_client:publish(Client, Topic, Payload, 0) of
        ok ->
            {ok, nil};
        {ok, _PacketId} ->
            {ok, nil};
        {error, Reason} when is_atom(Reason) ->
            {error, {other, atom_to_binary(Reason, utf8)}};
        {error, Reason} ->
            {error, {other, iolist_to_binary(io_lib:format("~p", [Reason]))}};
        error ->
            {error, failed}
    end.
