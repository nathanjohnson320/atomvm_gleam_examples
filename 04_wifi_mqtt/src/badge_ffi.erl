-module(badge_ffi).
-export([id/0]).

%% Last three bytes of the factory MAC, lower-case hex, so every badge gets
%% its own MQTT topic without anyone having to pick a number.
id() ->
    {ok, <<_:3/binary, Tail:3/binary>>} = esp:get_default_mac(),
    hex(Tail).

hex(<<>>) ->
    <<>>;
hex(<<Byte:8, Rest/binary>>) ->
    <<(nibble(Byte bsr 4)), (nibble(Byte band 16#0f)), (hex(Rest))/binary>>.

nibble(N) when N < 10 ->
    $0 + N;
nibble(N) ->
    $a + (N - 10).
