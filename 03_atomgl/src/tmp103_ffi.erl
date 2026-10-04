-module(tmp103_ffi).
-export([open/0, read_celsius/1]).

%% TMP103A on the badge I²C bus: SCL 10, SDA 11.
open() ->
    i2c:open([{scl, 10}, {sda, 11}, {clock_speed_hz, 100000}]).

%% Address 16#70. Pointer 16#00 is the temperature: one byte, two's complement.
read_celsius(Bus) ->
    {ok, <<Celsius:8/signed>>} = i2c:read_bytes(Bus, 16#70, 16#00, 1),
    Celsius.
