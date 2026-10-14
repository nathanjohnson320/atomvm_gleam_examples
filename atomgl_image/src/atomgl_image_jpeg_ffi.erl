%% Hot path for JPEG Huffman / bit IO on AtomVM (Gleam Dict is too slow here).
-module(atomgl_image_jpeg_ffi).
-export([
    map_from_list/1,
    make_block_ctx/4,
    decode_dc_and_discard_ac/5
]).

map_from_list(Pairs) when is_list(Pairs) ->
    maps:from_list(Pairs).

make_block_ctx(DcMap, AcMap, DcQuant, Pred) ->
    #{dc => DcMap, ac => AcMap, dc_quant => DcQuant, pred => Pred}.

%% Decode one block's DC, discard AC bits, return {Value0_255, NewPred, Data, Buf, Cnt, Pad}.
decode_dc_and_discard_ac(Data, Buf, Cnt, Pad, Ctx) ->
    try
        DcMap = maps:get(dc, Ctx),
        AcMap = maps:get(ac, Ctx),
        DcQuant = maps:get(dc_quant, Ctx),
        Pred = maps:get(pred, Ctx),
        R0 = {Data, Buf, Cnt, Pad},
        {Size, R1} = decode_huffman(R0, DcMap),
        {Diff, R2} = receive_extend(R1, Size),
        NewPred = Pred + Diff,
        Dc = NewPred * DcQuant,
        R3 = decode_ac_discard(R2, AcMap, 1),
        Value = clamp(((Dc + 4) bsr 3) + 128),
        {Data2, Buf2, Cnt2, Pad2} = R3,
        {ok, {Value, NewPred, Data2, Buf2, Cnt2, Pad2}}
    catch
        error:decode_failed -> {error, nil};
        _:_ -> {error, nil}
    end.

decode_ac_discard(R, _Ac, K) when K > 63 ->
    R;
decode_ac_discard(R0, Ac, K) ->
    {Symbol, R1} = decode_huffman(R0, Ac),
    Run = Symbol bsr 4,
    Size = Symbol band 15,
    case Size of
        0 when Run =:= 15 ->
            decode_ac_discard(R1, Ac, K + 16);
        0 ->
            R1;
        _ ->
            K2 = K + Run,
            case K2 > 63 of
                true ->
                    error(decode_failed);
                false ->
                    {_V, R2} = receive_extend(R1, Size),
                    decode_ac_discard(R2, Ac, K2 + 1)
            end
    end.

decode_huffman(R0, Table) ->
    decode_huffman(R0, Table, 0, 0).

decode_huffman(_R, _Table, _Code, Length) when Length >= 16 ->
    error(decode_failed);
decode_huffman(R0, Table, Code, Length) ->
    {Bit, R1} = read_bits(R0, 1),
    Code1 = Code * 2 + Bit,
    Length1 = Length + 1,
    Key = Length1 * 65536 + Code1,
    case maps:get(Key, Table, undefined) of
        undefined ->
            decode_huffman(R1, Table, Code1, Length1);
        Symbol ->
            {Symbol, R1}
    end.

receive_extend(R, 0) ->
    {0, R};
receive_extend(_R, Size) when Size > 15 ->
    error(decode_failed);
receive_extend(R0, Size) ->
    {Value, R1} = read_bits(R0, Size),
    case Value < (1 bsl (Size - 1)) of
        true ->
            {Value - (1 bsl Size) + 1, R1};
        false ->
            {Value, R1}
    end.

read_bits({Data, Buf, Cnt, Pad} = R, Count) when Cnt < Count ->
    read_bits(fill(R), Count);
read_bits({Data, Buf, Cnt, Pad}, Count) ->
    Remaining = Cnt - Count,
    Value = (Buf bsr Remaining) band ((1 bsl Count) - 1),
    {Value, {Data, Buf, Remaining, Pad}}.

fill({Data, Buf, Cnt, Pad}) ->
    Kept = ((Buf band ((1 bsl Cnt) - 1)) bsl 8),
    case Data of
        <<16#FF, 0, Rest/binary>> ->
            {Rest, Kept + 16#FF, Cnt + 8, Pad};
        <<16#FF, _/binary>> ->
            {Data, Kept, Cnt + 8, Pad + 1};
        <<>> ->
            {Data, Kept, Cnt + 8, Pad + 1};
        <<Byte, Rest/binary>> ->
            {Rest, Kept + Byte, Cnt + 8, Pad};
        _ ->
            {Data, Kept, Cnt + 8, Pad + 1}
    end.

clamp(V) when V < 0 -> 0;
clamp(V) when V > 255 -> 255;
clamp(V) -> V.
