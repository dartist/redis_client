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


  /// Specifies if this reply has been fully received.
  bool get done;


  /// Consumes the data and returns the uncosumed data if any, null otherwise.
  List<int> _consumeData(List<int> data);

}


/**
 * All replies that can only consist of one line extend this class.
 *
 * The line is always ended by CR LF.
 */
abstract class _OneLineReply extends RedisReply {


  final _OneLineDataConsumer _dataConsumer = new _OneLineDataConsumer();

  /**
   *  Specifies if this reply has been fully received.
   */
  bool get done => _dataConsumer.done;

  /**
   * Removes the leading type character and checks if the data contains
   * the ending CR LF characters.
   */
  @override
  List<int> _consumeData(List<int> data) {
    _dataConsumer.consumeData(data);

    if (_dataConsumer.done && _dataConsumer.unconsumedData != null) {
      return _dataConsumer.unconsumedData;
    }
    else {
      return null;
    }
  }

  String _line;

  /// Returns the line of this reply.
  String _getLine() {
    if (_line == null) {
      // [data] checks if this reply is [done] and fails if not.
      _line = decodeUtf8(_dataConsumer.data);
    }
    return _line;
  }

}


/// Used for status replies
class StatusReply extends _OneLineReply {

  /// Returns the status received with this reply.
  String get status => _getLine();

}

/// Used for error replies
class ErrorReply extends _OneLineReply {

  /// Returns the error received with this reply.
  String get error => _getLine();

}

/// Used for integer replies
class IntegerReply extends _OneLineReply {

  /// Returns the integer received with this reply.
  int get integer => int.parse(_getLine());

}

/// Used for bulk replies
class BulkReply extends RedisReply {

  final _OneLineDataConsumer _initialLineDataConsumer = new _OneLineDataConsumer();

  _BytesDataConsumer _dataConsumer;


  /**
   *  Specifies if this reply has been fully received.
   */
  bool get done {
    if (_dataConsumer == null) return false;
    else return _dataConsumer.done;
  }

  /**
   * Removes the leading type character and checks if the data contains
   * the ending CR LF characters.
   */
  @override
  List<int> _consumeData(List<int> data) {

    if (!_initialLineDataConsumer.done) {
      _initialLineDataConsumer.consumeData(data);

      // Can be null
      data = _initialLineDataConsumer.unconsumedData;

      if (data == null) {
        // Stop here.
        return null;
      }
    }

    // The initialLineConsumer has done it's job the last time or this time.
    // Either way, no it's time for the _dataConsumer to do it's job.
    if (_dataConsumer == null) {
      // Need to create the data consumer
      int byteLength = int.parse(new String.fromCharCodes(_initialLineDataConsumer.data));
      _dataConsumer = new _BytesDataConsumer(byteLength);
    }

    _dataConsumer.consumeData(data);

    if (_dataConsumer.done && _dataConsumer.unconsumedData != null) {
      return _dataConsumer.unconsumedData;
    }
    else {
      return null;
    }
  }


  /// Returns the raw bytes of this reply.
  List<int> get bytes {
    assert(_dataConsumer != null);
    // [_DataConsumer.data] checks if this reply is [done] and fails if not.
    return _dataConsumer.data;
  }


  String _dataAsString;

  /// Returns the reply as String.
  String get string {
    if (_dataAsString == null) {
      _dataAsString = decodeUtf8(bytes);
    }
    return _dataAsString;
  }


}


/**
 * This class differs a bit from the oder RedisReplies in that it actually
 * holds a list of mulitple [BulkReply]s.
 */
class MultiBulkReply extends RedisReply {

  /// Holds a list of [BulkReply] objects.
  List<BulkReply> bulkReplies;

}

