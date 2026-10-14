%% Host stub. On AtomVM, imports of jpeg:decode/2 bind to the C NIF instead.
-module(jpeg).
-export([decode/2]).

-spec decode(binary(), full | half | quarter | eighth) ->
    {ok, {non_neg_integer(), non_neg_integer(), binary()}}
    | {error, atom()}.
decode(_Data, _Scale) ->
    {error, no_nif}.
