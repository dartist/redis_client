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


  /// Specifies if this reply has been fully received.
  bool get done;


  /// Consumes the data and returns the uncosumed data if any, null otherwise.
  List<int> _consumeData(List<int> data);

  /// Default constructor does nothing.
  RedisReply();

  /**
   *  Factory constructor for [RedisReply] implementations.
   *
   *  Valid replies are:
   *
   *  - [ErrorReply]
   *  - [StatusReply]
   *  - [IntegerReply]
   *  - [BulkReply]
   *  - [MultiBulkReply]
   */
  factory RedisReply.fromType(int replyTypeChar) {

    // Now instantiate the correct RedisReply
    switch (replyTypeChar) {
      case RedisReply.STATUS:     return new StatusReply();
      case RedisReply.ERROR:      return new ErrorReply();
      case RedisReply.INTEGER:    return new IntegerReply();
      case RedisReply.BULK:       return new BulkReply();
      case RedisReply.MULTI_BULK: return new MultiBulkReply();
      default:
        throw new InvalidRedisResponseError("The type character was incorrect (${new String.fromCharCode(replyTypeChar)}).");
    }

  }

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
   * Consumes the first line with an [_OneLineDataConsumer], retrieves the
   * byteLength from it, and consumes the rest of the data with a
   * [_BytesDataConsumer].
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
    // Either way, now it's time for the _dataConsumer to do it's job.
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
 * holds a list of mulitple [RedisReply]s.
 */
class MultiBulkReply extends RedisReply {

  final _OneLineDataConsumer _initialLineDataConsumer = new _OneLineDataConsumer();

  /// The number of replies this multi bulk reply returns.
  int _numberOfReplies;

  /// Returns true if all replies have successfully been returned.
  bool get done {
    // Not even the inital first line has been received.
    if (_numberOfReplies == null) return false;

    // Not all replies have been received.
    if (_replies.length != _numberOfReplies) return false;

    // If the last reply is done, the [MultiBulkReply] is done.
    return _replies.last.done;
  }


  /// Holds the list of [RedisReply]s.
  List<RedisReply> _replies = <RedisReply>[ ];

  List<RedisReply> get replies {
    return _replies;
  }

  RedisReply get _lastReply => _replies.length > 0 ? _replies.last : null;

  /**
   * Consumes the first line with an [_OneLineDataConsumer], retrieves the
   * number of replies from it.
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
    // Now all replies have to be received.
    if (_replies.length == 0) {
      // The first line has completely been received.
      _numberOfReplies = int.parse(new String.fromCharCodes(_initialLineDataConsumer.data));
    }

    var lastReply = _lastReply;

    if (lastReply == null || lastReply.done) {
      // Need to create a new reply
      lastReply = new RedisReply.fromType(data.first);
      _replies.add(lastReply);
    }

    var unconsumedData = lastReply._consumeData(data);

    if (lastReply.done) {
      if (_replies.length == _numberOfReplies) {
        // All replies have been received.
        return unconsumedData;
      }
      else {
        _consumeData(unconsumedData);
      }
    }

    // Since the last reply is not done, there can't be any unconsumed data.
    return null;
  }

}
