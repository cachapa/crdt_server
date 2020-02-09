# CRDT Server

Generic REST server based on Conflict-free Replicated Data Types (CRDTs).

Serves as a demonstration of real-world use of the [CRDT package](https://github.com/cachapa/crdt).

This server listens for REST requests and maintains independent CRDTs for each route (created lazily).
It makes it trivial to test APIs by simply calling a '/users' or '/todo' routes.

## Usage

Simply run main.dart:

``` shell
$ cd crdt_server
$ pub get
$ dart bin/main.dart
Serving at http://localhost:8080
```

Perform a GET request against any path in the server to get the CRDT in JSON format:

``` shell
curl http://localhost:8080/todo
```

Merge an existing CRDT with the server using POST requests:

``` shell
curl -d '{"x":{"hlc":"2020-02-09T12:04:13.476Z-0000","value":{"Learn CRDTs":false}}}' http://localhost:8080/todo
```

## To do

- [ ] Monitor real-time changes using websockets
- [ ] Optional parameters for fetching CRDT subsets (partial merges)

## Features and bugs

Please file feature requests and bugs at the [issue tracker](https://github.com/cachapa/crdt_server/issues).
