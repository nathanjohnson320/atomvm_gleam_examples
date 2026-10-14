%% Scale ints → atoms, then jpeg:decode/2 (C NIF on AtomVM; stub on host OTP).
-module(atomgl_image_jpeg_nif).
-export([decode/2]).

-spec decode(binary(), 0..3) ->
    {ok, {non_neg_integer(), non_neg_integer(), binary()}} | {error, nil}.
decode(Data, Scale) when is_binary(Data), is_integer(Scale) ->
    Atom = case Scale of
        0 -> full;
        1 -> half;
        2 -> quarter;
        3 -> eighth;
        _ -> full
    end,
    case jpeg:decode(Data, Atom) of
        {ok, {W, H, Bin}} when is_integer(W), is_integer(H), is_binary(Bin) ->
            {ok, {W, H, Bin}};
        {error, _} ->
            {error, nil};
        _ ->
            {error, nil}
    end.
