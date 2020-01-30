import 'dart:convert';

import 'package:crdt/crdt.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

class CrdtServer {
  final _crdts = <String, Crdt>{};

  Future<void> serve(int port) async {
    var router = Router()
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
    if (!_crdts.containsKey(key)) {
      _crdts[key] = Crdt();
    }
    return _crdts[key];
  }
}
