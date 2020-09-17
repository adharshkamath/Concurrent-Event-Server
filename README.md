# Concurrent-Event-Server
A simple [event server](https://learnyousomeerlang.com/designing-a-concurrent-application) in Erlang


Supported functions:

- Client
    - Create and subscribe to events
    - Cancel subscription to a particular event
    - Monitor the condition of the server
    - Shutdown the server if needed

- Server
    - Accept subscription requests from clients
    - Accept requests to create events and forward notifications from events to clients
    - Accept cancellation requests for events from clients
    - Hot code reloading

An Event in the above context consists of a name, description and a waiting time after which it will be fired.