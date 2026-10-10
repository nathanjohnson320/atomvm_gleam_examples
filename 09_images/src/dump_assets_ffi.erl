-module(dump_assets_ffi).
-export([
    read_file/1,
    write_bits/2,
    write_string/2,
    make_dir/1,
    list_dir/1,
    delete/1
]).

read_file(Path) ->
    case file:read_file(Path) of
        {ok, Bin} -> {ok, Bin};
        {error, Reason} -> {error, reason_to_string(Reason)}
    end.

write_bits(Path, Data) ->
    case file:write_file(Path, Data) of
        ok -> {ok, nil};
        {error, Reason} -> {error, reason_to_string(Reason)}
    end.

write_string(Path, Data) when is_binary(Data) ->
    write_bits(Path, Data);
write_string(Path, Data) when is_list(Data) ->
    write_bits(Path, unicode:characters_to_binary(Data)).

make_dir(Path) ->
    case file:make_dir(Path) of
        ok -> {ok, nil};
        {error, eexist} -> {error, <<"eexist">>};
        {error, Reason} -> {error, reason_to_string(Reason)}
    end.

list_dir(Path) ->
    case file:list_dir(Path) of
        {ok, Names} ->
            {ok, [unicode:characters_to_binary(Name) || Name <- Names]};
        {error, Reason} ->
            {error, reason_to_string(Reason)}
    end.

delete(Path) ->
    case file:delete(Path) of
        ok -> {ok, nil};
        {error, Reason} -> {error, reason_to_string(Reason)}
    end.

reason_to_string(Reason) when is_atom(Reason) ->
    atom_to_binary(Reason, utf8);
reason_to_string(Reason) ->
    iolist_to_binary(io_lib:format("~p", [Reason])).
