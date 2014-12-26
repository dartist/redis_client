part of redis_protocol_transformer;

class RedisReply {}

class StatusReply extends RedisReply {
  StatusReply(this.status);
  String toString() => "StatusReply: $status";
  final String status;
}

class ErrorReply extends RedisReply {
  ErrorReply(this.error);
  String toString() => "ErrorReply: $error";
  final String error;
}

class IntegerReply extends RedisReply {
  IntegerReply(this.integer);
  String toString() => "IntegerReply: $integer";
  final int integer;
}

class BulkReply extends RedisReply {
  BulkReply(this.bytes);

  String get string {
    if(_dataAsString == null) {
      _dataAsString = bytes == null? bytes : UTF8.decode(bytes);
    }
    return _dataAsString;
  }

  String _dataAsString;
  final List<int> bytes;
}

class MultiBulkReply extends RedisReply {
  MultiBulkReply(this.replies);
  final List<RedisReply> replies;
}
