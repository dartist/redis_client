
/**
 * This is a [StreamTransformer] for redis Socket replies.
 *
 * It converts a binary stream from a redis socket to [RedisReply] objects.
 *
 * You can use the transformer in a Socket like this:
 *
 *     socket.transform(new RedisProtocolTransformer()).listen((RedisReply reply) { });
 *
 * There are five types of [RedisReply]s:
 *
 *  - [ErrorReply]
 *  - [StatusReply]
 *  - [IntegerReply]
 *  - [BulkReply]
 *  - [MultiBulkReply]
 */
library redis_protocol_transformer;

import "dart:async";
import "dart:collection";
import "dart:typed_data";
import "dart:utf";
import "package:meta/meta.dart";

part 'transformer/transformer.dart';

part 'transformer/data_consumers.dart';

part 'transformer/redis_replies.dart';

