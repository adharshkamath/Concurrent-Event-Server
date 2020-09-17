-module(event).
-compile(export_all).
-record(state, {
    server,
    name = "",
    to_go=0
}).

start(EventName, DateTime) ->
    spawn(?MODULE, init, [self(), EventName, DateTime]).

start_link(EventName, DateTime) ->
    spawn_link(?MODULE, init,[self(), EventName, DateTime]).

init(Server, EventName, DateTime) ->
    loop(#state{server=Server, name=EventName, to_go=time_to_go(DateTime)}).

loop(S = #state{server=Server, to_go=[Time|Next]}) ->
    receive
        {Server, Reference, cancel} ->
            Server ! {Reference, ok}
    after Time*1000 ->
        if Next =:= [] ->
            Server ! {done, S#state.name};
            Next =/= [] ->
                loop(S#state{to_go=Next})
        end
    end.

normalize(N) ->
    Limit = 49*24*60*60,
    [N rem Limit | lists:duplicate(N div Limit, Limit)].

cancel(PId) ->
    Ref = monitor(process, PId),
    PId ! {self(), Ref, cancel},
    receive
        {Ref, ok} ->
            demonitor(Ref, [flush, info]),
            ok;
        {'DOWN', Ref, process, PId, _Reason} ->
            ok
    end.

time_to_go(TimeOut = {{_, _, _}, {_, _, _}}) ->
    TimeNow = calendar:local_time(),
    TimeLeft = calendar:datetime_to_gregorian_seconds(TimeOut) - 
                calendar:datetime_to_gregorian_seconds(TimeNow),
    Seconds = if TimeLeft > 0 -> TimeLeft;
                true -> 0
                end,
    normalize(Seconds).