%% Wait for `{got_ip, Info}` after `network:start/1` with a notify pid.
%% Distinguishes associate-without-DHCP from total silence (useful on GoPro AP).
-module(gopro_net_ffi).
-export([await_got_ip/1]).

-spec await_got_ip(non_neg_integer()) ->
    {ok, {{byte(), byte(), byte(), byte()},
          {byte(), byte(), byte(), byte()},
          {byte(), byte(), byte(), byte()}}}
  | {error, binary()}.
await_got_ip(TimeoutMs) when is_integer(TimeoutMs), TimeoutMs >= 0 ->
    flush_stale(),
    await_got_ip(TimeoutMs, erlang:monotonic_time(millisecond), false).

await_got_ip(TimeoutMs, Start, Associated) ->
    Elapsed = erlang:monotonic_time(millisecond) - Start,
    Remaining = TimeoutMs - Elapsed,
    case Remaining =< 0 of
        true ->
            case Associated of
                true -> {error, <<"associated_no_ip">>};
                false -> {error, <<"timeout">>}
            end;
        false ->
            receive
                {got_ip, {Address, Netmask, Gateway}} ->
                    {ok, {Address, Netmask, Gateway}};
                disconnected ->
                    {error, <<"disconnected">>};
                connected ->
                    await_got_ip(TimeoutMs, Start, true);
                _Other ->
                    await_got_ip(TimeoutMs, Start, Associated)
            after Remaining ->
                case Associated of
                    true -> {error, <<"associated_no_ip">>};
                    false -> {error, <<"timeout">>}
                end
            end
    end.

flush_stale() ->
    receive
        connected -> flush_stale();
        disconnected -> flush_stale();
        {got_ip, _} -> flush_stale();
        _ -> flush_stale()
    after 0 ->
        ok
    end.
