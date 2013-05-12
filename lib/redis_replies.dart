part of redis_protocol_transformer;

/**
 * Base class for redis replies.
 *
 * Every time a new redis reply is received, this class is instantiated,
 * and returned with the corresponding data.
 */
abstract class RedisReply {

  /// A reply type
  static const int STATUS = RedisProtocolTransformer.PLUS;

  /// A reply type
  static const int ERROR = RedisProtocolTransformer.DASH;

  /// A reply type
  static const int INTEGER = RedisProtocolTransformer.COLON;

  /// A reply type
  static const int BULK = RedisProtocolTransformer.DOLLAR;

  /// A reply type
  static const int MULTI_BULK = RedisProtocolTransformer.ASTERIX;

  /// A list of all defined types.
  static const List<int> TYPES = const [ STATUS, ERROR, INTEGER, BULK, MULTI_BULK ];


  List<int> _data = [ ];

  /// Used to add data to this reply.
  void addData(List<int> newData) => _data.addAll(newData);


  /**
   * Gets called with the data block and consumes as much as it needs.
   *
   * If it consumes all of the data (either because some data is still missing
   * or because all of the data has been used as a reply) it should return null.
   *
   * This function should set [done] to true if all data for this reply has been
   * provided.
   */
  List<int> _consumeData(List<int> newData);

  bool _done = false;

  /// Specifies if this reply has been fully received.
  bool get done => _done;

}


class StatusReply extends RedisReply {


  String _status;

  /// Returns the status received with this reply.
  String get status {
    if (_status == null) {
      _status = new String.fromCharCodes(_data);
    }
    return _status;
  }

}

class ErrorReply extends RedisReply {

}

class IntegerReply extends RedisReply {

}

class BulkReply extends RedisReply {

}


/**
 * This class differs a bit from the oder RedisReplies in that it actually
 * holds a list of mulitple [BulkReply]s.
 */
class MultiBulkReply extends RedisReply {

  /// Holds a list of [BulkReply] objects.
  List<BulkReply> bulkReplies;

}

