
/**
 * A redis client that communicates with redis through a socket and exposes
 * a high level API.
 *
 * Internally, it uses the [RedisProtocolTransformer] to transform binary
 * data from the socket to formatted [RedisReply]s.
 *
 * Please see the [RedisClient] documentation for detailed documentation on
 * how to use this library.
 */
library redis_client;

import 'dart:io';
import 'dart:json';
import 'dart:utf';
import 'dart:math' as Math;
import 'dart:typed_data';
import 'dart:isolate';
import 'dart:async';
import 'dart:collection';
import 'package:logging/logging.dart';


import 'redis_protocol_transformer.dart';

part 'src/redis_client_commands.dart';
part 'src/redis_serializer.dart';
part 'src/command_utils.dart';
part 'src/redis_client.dart';
part 'src/raw_redis_commands.dart';
part 'src/redis_connection.dart';
part 'src/connection_settings.dart';
//part 'src/in_memory_redis_client.dart';

