-module(evserv).
-compile(export_all).
-record(state, {
    events,
    clients 
}).
-record(event, {
    name="",
    description="",
    pid,
    timeout={{1970,1,1},{0,0,0}}
}).


init() ->
    loop(#state{
        events=orddict:new(),
        clients=orddict:new()    
    }).

start() ->
    register(?MODULE, Pid = spawn(?MODULE, init, [])),
    Pid.
 
start_link() ->
    register(?MODULE, Pid = spawn_link(?MODULE, init, [])),
    Pid.

terminate() ->
    ?MODULE ! shutdown.

loop(S = #state{}) ->
    receive
        {Pid, MsgRef, {subscribe, Client}} ->
            Ref = erlang:monitor(process, Client),
            NewClients = orddict:store(Ref, Client, S#state.clients),
            Pid ! {MsgRef, ok},
            loop(S#state{clients=NewClients});
        {Pid, MsgRef, {add, Name, Description, TimeOut}} ->
            case valid_date_time(TimeOut) of
                true ->
                    EventPid = event:start_link(Name, TimeOut),
                    NewEvents = orddict:store(Name, 
                                            #event{
                                                name=Name, 
                                                description=Description,
                                                pid=EventPid,
                                                timeout=TimeOut},
                                            S#state.events),
                    Pid ! {MsgRef, ok},
                    loop(S#state{events=NewEvents});
                false -> 
                    Pid ! {MsgRef, {error, bad_timeout}},
                    loop(S)
            end;
        {Pid, MsgRef, {cancel, EventName}} ->
            NewEvents = case orddict:find(EventName, S#state.events) of
                        {ok, Event} ->
                            event:cancel(Event#event.pid),
                            orddict:erase(EventName, S#state.events);
                        error -> 
                            S#state.events
                    end,
                Pid ! {MsgRef, ok},
                loop(S#state{events=NewEvents});
        {done, EventName} ->
            case orddict:find(EventName, S#state.events) of 
                {ok, Event} ->
                    send_to_clients({done, Event#event.name, Event#event.description}, S#state.clients),
                    NewEvents = orddict:erase(Event, S#state.events),
                    loop(S#state{events=NewEvents});
                error ->
                    loop(S)
            end;
        shutdown ->
            exit(shutdown);
        {'DOWN', Ref, process, _Pid, _Reason } ->
            loop(S#state{clients = orddict:erase(Ref, S#state.clients)});
        code_change ->
            ?MODULE:loop(S);
        Unknown ->
            io:format("Unkknown Message ~p~n", [Unknown]),
            loop(S)
    end.


send_to_clients(Message, ClientDict) ->
    orddict:map(fun(_Ref, Pid) -> Pid ! Message end, ClientDict).

valid_date_time({Date, Time}) ->
    try
        calendar:valid_date(Date) andalso valid_time(Time)
    catch
        error:function_clause -> false  % Input not in {{Y,M,D},{H,Min,S}} format
    end;
valid_date_time(_) -> false.

valid_time({H, M, S}) ->
    valid_time(H, M, S).

valid_time(H, M, S) when H >= 0, H < 24,
    M >= 0, M < 60,
    S >= 0, S < 60 -> true;
valid_time(_, _, _) -> false.

subscribe(Pid) ->
    Ref = erlang:monitor(process, whereis(?MODULE)),
    ?MODULE ! {self(), Ref, {subscribe, Pid}},
    receive
        {Ref, ok} ->
            {ok, Ref};
        {'DOWN', Ref, process, _Pid, Reason } ->
            {error, Reason}
    after 5000 ->
        {error, timeout}
    end.

add_event(Name, Description, TimeOut) ->
    Ref = make_ref(),
    ?MODULE ! {self(), Ref, {add, Name, Description, TimeOut }},
    receive
        {Ref, {error, Reason}} -> erlang:error(Reason);
        {Ref, Message} -> Message
        after 5000 -> 
            {error, timeout}
    end.

cancel(EventName) ->
    Ref = make_ref(),
    ?MODULE ! {self(), Ref, {cancel, EventName}},
    receive
        {Ref, ok} -> ok
    after 5000 ->
        {error, timeout}
    end.

listen(Duration) ->
    receive
        Message = {done, _EventName, _EventDesc } ->
            [Message | listen(0)]
    after Duration*1000 ->
        []
    end.