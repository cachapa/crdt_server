import 'dart:async';
import 'dart:convert';

import 'package:crdt/crdt.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';

class CrdtServer {
  final _crdts = <String, Crdt>{};
  final _streams = <Crdt, CrdtStream>{};

  Future<void> serve(int port) async {
    var router = Router()
      ..get('/<ignored|.*>/ws', _wsHandler)
      ..get('/<ignored|.*>', _getCrdtHandler)
      ..post('/<ignored|.*>', _postCrdtHandler)
      // Return 404 for everything else
      ..all('/<ignored|.*>', _notFoundHandler);

    var handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(router.handler);

    var server = await io.serve(handler, 'localhost', port);
    print('Serving at http://${server.address.host}:${server.port}');
  }

  Future<Response> _getCrdtHandler(Request request) async {
    var crdt = _getCrtd(request);
    return await _crdtResponse(crdt);
  }

  Future<Response> _postCrdtHandler(Request request) async {
    var crdt = _getCrtd(request);

    try {
      var json = await request.readAsString();
      await _merge(crdt, json);
      return await _crdtResponse(crdt);
    } on ClockDriftException catch (e) {
      return _errorResponse(e);
    }
  }

  Future<void> _merge(Crdt crdt, String json) async {
    var map = json2CrdtMap(json);
    print('<= $map');
    await crdt.merge(map);
    _streams[crdt]?.add(crdtMap2Json(await crdt.getMap()));
    print('=> ${await crdt.getMap()}');
  }

  Future<Response> _crdtResponse(Crdt crdt) async {
    var body = jsonEncode(await crdt.getMap());
    return Response.ok(body);
  }

  Response _errorResponse(Exception e) => Response(412, body: '$e');

  Response _notFoundHandler(Request request) => Response.notFound('Not found');

  Crdt _getCrtd(Request request) {
    var key = request.url.path;
    if (key.endsWith('/ws')) key = key.substring(0, key.length - 3);

    if (!_crdts.containsKey(key)) {
      _crdts[key] = Crdt();
    }
    return _crdts[key];
  }

  CrdtStream _getStream(Crdt crdt) {
    if (!_streams.containsKey(crdt)) {
      _streams[crdt] = CrdtStream();
    }
    return _streams[crdt];
  }

  Response _wsHandler(Request request) {
    var crdt = _getCrtd(request);
    var crdtStream = _getStream(crdt);

    var handler = webSocketHandler((webSocket) async {
      print('Client connected to ${request.url.path}');

      webSocket.sink.addStream(crdtStream.stream);

      webSocket.stream.listen((message) => _merge(crdt, message), onDone: () {
        crdtStream.close();
        _streams.remove(crdt);
        print('Client disconnected from ${request.url.path}');
      });
    });

    return handler(request);
  }
}

class CrdtStream {
  final _controller = StreamController<String>();

  Stream<String> _stream;

  Stream<String> get stream => _stream;

  CrdtStream() {
    _stream = _controller.stream.asBroadcastStream();
  }

  void add(String event) => _controller.add(event);

  void close() => _controller.close();
}
