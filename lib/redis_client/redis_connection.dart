part of redis_client;



/// The [RedisConnection] wraps the Socket, and provides an API to communicate
/// to redis.
///
/// You instantiate a [RedisConnection] with:
///
///     RedisConnection.connect(connectionString)
///         .then((RedisConnection connection) {
///           // Use your connection
///         });
///
/// where `connectionString` can be any of following:
///
/// - `'pass@host:port/db'`
/// - `'pass@host:port'`
/// - `'pass@host'`
/// - `'host'`
/// - `null` defaults to `'localhost:6379/0'`
abstract class RedisConnection {


  /// Create a new [RedisConnection] with given connectionString.
  static Future<RedisConnection> connect(String connectionString) => _RedisConnection.connect(connectionString);



  /// The connectionString from which the connection settings have been
  /// extruded.
  ///
  /// Once this string has been parsed, it isn't used anymore.
  String connectionString;

  /// Redis connection hostname
  String hostname;

  /// Redis connection password
  String password;

  /// Redis connection port
  int port;

  /// Redis database
  int db;

  Future auth(String password);

  /// Closes the connection.
  Future close();


  Map get stats;


  Future select([ int db ]);

  /// Convenient method to send [String] commands.
  Receiver send(List<String> cmdWithArgs);

  /// Convenient method to send a command with a list of [String] arguments.
  Receiver sendCommand(List<int> command, List<String> args);


  /// Convenient method to send a command with a list of [String] arguments
  /// and a list of [String] values.
  Receiver sendCommandWithVariadicValues(List<int> command, List<String> args, List<String> values);


  /// Sends the commands already in binary.
  Receiver rawSend(List<List<int>> cmdWithArgs);


  /// Subscribes to [List<String>] channels with [Function] onMessage handler
  Future subscribe(List<String> channels, Function onMessage);


  /// Unubscribes from [List<String>] channels
  Future unsubscribe(List<String> channels);
}


/// The actual implementation of the [RedisConnection].
class _RedisConnection extends RedisConnection {


  // Connection settings

  final String connectionString;

  final String hostname;

  final String password;

  final int port;

  int db;

  /// The [Socket] used in this connection.
  Socket _socket;

  RedisStreamTransformerHandler _streamTransformerHandler = new RedisStreamTransformerHandler();

  // /// The current consumer
  _RedisConsumer _consumer;


  /// The completer that resolves the future as soon as the RedisConnection
  /// is connected.
  final Completer<RedisConnection> _connectedCompleter = new Completer<RedisConnection>();

  /// Gets resolved as soon as the connection is up.
  Future<RedisConnection> connected;


  /// The character sequence that ends data.
  ///
  /// `\r\n`
  static const List<int> _lineEnd = const [ 13, 10 ];


  /// Used to output debug information
  Logger logger = new Logger("redis_client");



  Int8List _cmdBuffer = new Int8List(32 * 1024);

  int _cmdBufferIndex = 0;

  // To Reduce Reallocations
  static final int breathingSpace = 32 * 1024;

  /// Statistics
  int totalBuffersWrites = 0;

  /// Statistics
  int totalBufferFlushes = 0;

  /// Statistics
  int totalBufferResizes = 0;

  /// Statistics
  int totalBytesWritten = 0;

  /// TODO actually implement.
  Map get stats => throw new UnsupportedError("Not done yet");


  /**
   * Creates a [RedisConnection], and returns the future for a connection.
   *
   * Please refere to the [RedisConnection] documentation for a list of valid
   * connection strings.
   */
  static Future<RedisConnection> connect(String connectionString) {
    var settings = new RedisConnectionSettings(connectionString);

    var redisConnection = new _RedisConnection(settings.connectionString, settings.hostname, settings.password, settings.port, settings.db);

    return redisConnection.connected.then((_) => redisConnection);
  }


  /// Create a new [RedisConnection] with given connectionString.
  _RedisConnection(this.connectionString, this.hostname, this.password, this.port, this.db) {

    logger.info("Creating socket connection ($hostname, $port)");

    this.connected = Socket.connect(hostname, port)
        .then((Socket socket) {
          logger.info("Connected socket");

          _socket = socket;
          //disable Nagle's algorithm
          socket.setOption(SocketOption.TCP_NODELAY,true);

          // Setting up all the listeners so Redis responses can be interpreted.
          socket
            .transform(_streamTransformerHandler.createTransformer())
            .listen(_onRedisReply, onError: _onStreamError, onDone: _onStreamDone);

          if (password != null) return _authenticate(password);
        })
        .then((_) {
          if (db > 0) return select();
        })
        // The RedisConnection has connected successfully.

        .catchError(_onSocketError);

  }

  Future auth(String _password) {
    this.password = _password;
    return sendCommand(RedisCommand.AUTH, [ _password ]).receive();
  }


  /// Closes the connection.
  Future close() {
    logger.fine("Closing connection.");
    return this.connected.then((_) => _socket.close());
  }


  /// Selects configured database.
  ///
  /// If db is provided the configuration [db] will be set to it.
  Future select([ int db ]) {
    if (db != null) this.db = db;
    return send([ "SELECT", db.toString() ]).receive();
  }

  /// Authenticates with configured password.
  Future _authenticate(String _password) => send([ "AUTH", password ]).receive();



  /// Gets called when the socket has an error.
  void _onSocketError(err) {
    logger.warning("Socket error $err.");
    throw new RedisClientException("Socket error $err.");
  }

  Function _subscriptionHandler = null;

  Future subscribe(List<String> channels, Function onMessage){

    Completer subscribeCompleter = new Completer();
    List<String> args = new List <String>()
        ..add("SUBSCRIBE")
        ..addAll(channels);

    send(args).receive().then((val){
      _subscriptionHandler = onMessage;
      subscribeCompleter.complete();
    });
    return subscribeCompleter.future;
  }

  Future unsubscribe(List<String> channels){
    Completer unsubscribeCompleter = new Completer();
    List<String> args = new List <String>()
        ..add("UNSUBSCRIBE")
        ..addAll(channels);

    _subscriptionHandler = null;
    send(args).receive().then((val){
      unsubscribeCompleter.complete();
    });
    return unsubscribeCompleter.future;
  }

  /// Handles new data received from stream.
  void _onRedisReply(RedisReply redisReply) {
    logger.fine("Received reply: $redisReply");

    if(_subscriptionHandler != null){
      Receiver rec = new Receiver()
      ..reply = redisReply;
      _subscriptionHandler(rec);
      return;
    }
    if (_pendingResponses.length == 0 || _pendingResponses.last.reply != null) {
      if (redisReply is ErrorReply) {
        logger.warning("Received error from redis: ${redisReply.error}");
      }
      throw new RedisClientException("Received data without expecting any ($redisReply).");
    }

    for (var response in _pendingResponses) {
      if (response.reply == null) {
        response.reply = redisReply;
        return;
      }
    }
  }

  /// Handles stream errors
  void _onStreamError(err) {
    logger.warning("Stream error $err");
    _socket.close();
    throw new RedisClientException("Received stream error $err.");
  }

  /// Gets called when the stream closes.
  void _onStreamDone() {
    logger.fine("Stream finished.");
  }


  List<Receiver> _pendingResponses = <Receiver>[ ];

  /**
   * Returns a [Receiver] on which you can get a future of a specific type.
   *
   * Eg.:
   *
   *     send([ "COMMAND" ]).receiveInteger().then((int number) { });
   *
   * This function converts the [String]s to binary data, and forwards to
   * [rawSend].
   */
  Receiver send(List<String> cmdWithArgs) => rawSend(cmdWithArgs.map((String line) => UTF8.encode(line)).toList(growable: false));


  /**
   * Conveniance wrapper for `rawSend`.
   *
   * The command is one of [RedisCommand].
   */
  Receiver sendCommand(List<int> command, List<String> args) {
    var commands = new List<List<int>>(args.length + 1);
    commands[0] = command;
    commands.setAll(1, args.map((String line) => UTF8.encode(line)).toList(growable: false));
    return rawSend(commands);
  }

  Receiver sendCommandWithVariadicValues(List<int> command, List<String> args, List<String> values) {
    var commands = new List<List<int>>(args.length + values.length + 1);
    commands[0] = command;
    commands.setAll(1, args.map((String line) => UTF8.encode(line)).toList(growable: false));
    commands.setAll(args.length + 1, values.map((String line) => UTF8.encode(line)).toList(growable: false));
    return rawSend(commands);
  }

  /**
   * This is the same as [send] except that it takes a list of binary data.
   *
   * Eg.:
   *
   *     rawSend([ "GET".codeUnits, UTF8.encode("keyname") ]).receiveBulkString().then((String value) { });
   */
  Receiver rawSend(List<List<int>> cmdWithArgs) {
    var response = new Receiver();

    logger.finest("Sending message ${UTF8.decode(cmdWithArgs[0])}");

    _socket.add("*${cmdWithArgs.length}\r\n".codeUnits);
    cmdWithArgs.forEach((line) {
      _socket.add("\$${line.length}\r\n".codeUnits);

      // Write the line, and the line end
      _socket.add(line);
      _socket.add(_lineEnd);
    });

    _pendingResponses.add(response);

    return response;
  }

}


/**
 * Class that handles responses from the redis socket, and serves the replies.
 *
 * This class gets returned when calling [RedisConnection.send] and serves as
 * a proxy for the actual [RedisReply] object.
 */
class Receiver {

  /// Gets set when received.
  RedisReply _reply;

  RedisReply get reply => _reply;

  /// Will automatically resolve all futures requested with this response.
  void set reply(reply) {
    _reply = reply;
    _receivedCompleter.complete(reply);
  }

  Future<RedisReply> _received;

  Completer<RedisReply> _receivedCompleter = new Completer<RedisReply>();

  /**
   * You should never need to create a [Receiver] instance yourself.
   */
  Receiver() {
    _received = _receivedCompleter.future;
  }

  /**
   * Returns a [Future] that gets resolved and doesn't check the return value.
   *
   * Note that **all** redis replies are checked for valid syntax and format.
   * This reply just doesn't check for a specific reply type.
   */
  Future<RedisReply> receive() => _received;

  /**
   * Checks that the received reply is of type [IntegerReply].
   */
  Future<int> receiveInteger() {
    return _received.then((reply) {
      if (reply is! IntegerReply) {
        var error = "";
        if (reply is ErrorReply) {
          error = " Error: ${reply.error}";
        }
        throw new RedisClientException("The returned reply was not of type IntegerReply but ${reply.runtimeType}.${error}");
      }
      return reply.integer;
    });
  }


  /**
   * Uses [receiveBulkString] and casts it to a double.
   */
  Future<double> receiveDouble() {
    return receiveBulkString().then((doubleString) => double.parse(doubleString));
  }


  /**
   * Checks that the received reply is of type [ErrorReply].
   */
  Future<String> receiveError() {
    return _received.then((reply) {
      if (reply is! ErrorReply) {

        throw new RedisClientException("The returned reply was not of type ErrorReply but ${reply.runtimeType}");
      }
      return reply.error;
    });
  }


  /**
   * Checks that the received reply is of type [IntegerReply] and returns `true`
   * if `1` and `false` otherwise.
   */
  Future<bool> receiveBool() {
    return receiveInteger().then((int value) => value == 1 ? true : false);
  }


  /**
   * Checks that the received reply is of type [StatusReply].
   */
  Future<String> receiveStatus([ String expectedStatus ]) {
    return _received.then((reply) {
      if (reply is! StatusReply) {
        var error = "";
        if (reply is ErrorReply) {
          error = " Error: ${reply.error}";
        }
        throw new RedisClientException("The returned reply was not of type StatusReply but ${reply.runtimeType}.${error}");
      }
      if (expectedStatus != null && (expectedStatus != reply.status)) {
        throw new RedisClientException("The returned status was not $expectedStatus but ${reply.status}.");
      }
      return reply.status;
    });
  }

  /**
   * Checks that the received reply is of type [BulkReply] and returns the byte
   * list.
   */
  Future<List<int>> receiveBulkData() {
    return _received.then((reply) {
      if (reply is! BulkReply) {
        var error = "";
        if (reply is ErrorReply) {
          error = " Error: ${reply.error}";
        }
        throw new RedisClientException("The returned reply was not of type BulkReply but ${reply.runtimeType}.${error}");
      }
      return reply.bytes;
    });
  }

  /**
   * Checks that the received reply is of type [BulkReply] and returns a [String].
   */
  Future<String> receiveBulkString() {
    return _received.then((reply) {
      if (reply is! BulkReply) {
        var error = "";
        if (reply is ErrorReply) {
          error = " Error: ${reply.error}";
        }
        throw new RedisClientException("The returned reply was not of type BulkReply but ${reply.runtimeType}.${error}");
      }
      return reply.string;
    });
  }

  /**
   * Returns the data received by this bulk reply deserialized.
   */
  Future<Object> receiveBulkDeserialized(RedisSerializer serializer) {
    return receiveBulkData().then(serializer.deserialize);
  }

  /**
   * Checks that the received reply is of type [MultiBulkReply].
   */
  Future<MultiBulkReply> receiveMultiBulk() {
    return _received.then((reply) {
      if (reply is! MultiBulkReply) {
        var error = "";
        if (reply is ErrorReply) {
          error = " Error: ${reply.error}";
        }
        throw new RedisClientException("The returned reply was not of type MultiBulkReply but ${reply.runtimeType}.${error}");
      }
      return reply;
    });
  }

  /**
   * Checks that the received reply is of type [MultiBulkReply] and returns a list
   * of strings.
   */
  Future<List<String>> receiveMultiBulkStrings() {
    return receiveMultiBulk().then((MultiBulkReply reply) {
      return reply.replies.map((BulkReply reply) => reply.string).toList(growable: false);
    });
  }

  /**
   * Checks that the received reply is of type [MultiBulkReply] and returns a list
   * of deserialized objects.
   */
  Future<List<Object>> receiveMultiBulkDeserialized(RedisSerializer serializer) {
    return receiveMultiBulk().then((MultiBulkReply reply) {
      return reply.replies.map(
          (BulkReply reply) => serializer.deserialize(reply.bytes)).toList(growable: false);
    });
  }

  /**
   * Checks that the received reply is of type [MultiBulkReply] and returns a set
   * of deserialized objects.
   */
  Future<Set<Object>> receiveMultiBulkSetDeserialized(RedisSerializer serializer) {
    return receiveMultiBulk().then((MultiBulkReply reply) {
      return reply.replies.map(
          (BulkReply reply) => serializer.deserialize(reply.bytes)).toSet();
    });
  }

  /**
   * Checks that the received reply is of type [MultiBulkReply] and returns a map
   * of String keys and deserialized objects.
   */
  Future<Map<String, Object>> receiveMultiBulkMapDeserialized(RedisSerializer serializer) {
    return receiveMultiBulk().then((MultiBulkReply reply) {
      return serializer.deserializeToMap(reply.replies);
    });
  }


  /**
   * Checks that the received reply is either [ErrorReply], [StatusReply] or
   * [BulkReply] and returns the [String] of it.
   */
  // I think this function should not be implemented.
  // Getting an error instead of an expected string should not be default behavior.
//  Future<String> receiveString() {
//    return _received.then((reply) {
//      if (reply is ErrorReply) {
//        return reply.error;
//      }
//      else if (reply is StatusReply) {
//        return reply.status;
//      }
//      else if (reply is BulkReply) {
//        return reply.string;
//      }
//      else {
//        throw new RedisClientException("Couldn't get a string of type ${reply.runtimeType}.");
//      }
//    });
//  }

}


final int _CR = 13;
final int _LF = 10;

const int _STATUS = 43;
const int _ERROR = 45;
const int _INTEGER = 58;
const int _BULK = 36;
const int _MULTI_BULK = 42;

/// Establishes base for the consumers of redis data
///
/// The pattern for the consume method is indexed base, meaning consumers are
/// supplied a (start, end] on which to work and they return the index of the
/// next datum to be consumed.
abstract class _RedisConsumer {

  /// consume data from start index up to end (exclusive) index returning the
  /// next index to be consumed if done
  int consume(List<int> data, int start, int end);

  // Create RedisReply from consumed data (requires done == true)
  RedisReply makeReply();

  bool get done;

  List<int> get data {
    assert(done);

    if(_data == null) {
      final dataSize = _dataBlocks.fold(0, (int prevValue, List dataBlock) =>
          prevValue + dataBlock.length);
      if(dataSize == 0) {
        return _data;
      } else {
        _data = new List<int>(dataSize - 2);
        var blocksNeeded = _dataBlocks.length;
        var ignoredCharacters = 2;
        if(_dataBlocks.last.length == 1) {
          assert(_dataBlocks.last.last == _LF);
          ignoredCharacters--;
          blocksNeeded--;
          assert(_dataBlocks[blocksNeeded-1].last == _CR);
        }

        var stringIndex = 0;
        for(var blockIndex=0; blockIndex < blocksNeeded; blockIndex++) {
          final currentBlock = _dataBlocks[blockIndex];
          bool isLastBlock = blockIndex == blocksNeeded - 1;
          final charsToTake = currentBlock.length - (isLastBlock? ignoredCharacters:0);

          _data.setAll(stringIndex,
              isLastBlock?
              currentBlock.take(currentBlock.length - ignoredCharacters) :
              currentBlock);

          stringIndex += charsToTake;
        }
      }
    }
    return _data;
  }

  /// Blocks of data consumed
  final List<List<int>> _dataBlocks = [];

  /// The joined _dataBlocks - lazy initilialized to join via `get data` call
  /// which at that point strips the CR,LF
  List<int> _data;

}

/// Consumes a single line of data
abstract class _LineConsumer extends _RedisConsumer {

  int consume(List<int> data, final int start, final int end) {
    assert(start < end);
    ///////////////////////////////////////////////////////////////////////////
    // Iterate looking for CR,LF to end the line. If we have data already, use
    // the last character saved as check for CR in CR,LF. Otherwise start at
    // beginning of data
    ///////////////////////////////////////////////////////////////////////////
    bool haveSome = !_dataBlocks.isEmpty;

    var prevChar = haveSome? _dataBlocks.last.last : data[start];
    int current = haveSome? start : start + 1;

    for(; current < end; current++) {
      final nextChar = data[current];
      if(prevChar == _CR && nextChar == _LF) {
        _done = true;
        current++;
        break;
      }
      prevChar = nextChar;
    }

    _dataBlocks.add(new UnmodifiableListView(data.getRange(start, current)));

    // we've advanced and either are done or ran out
    assert(current > start && (done || current == end));

    return current;
  }

  String get line => _line == null? (_line = UTF8.decode(data)) : _line;
  bool get done => _done;

  /// The line data as String
  String _line;
  /// Done reading the single line
  bool _done = false;
}

/// Consumes the bulk type redis reply
class _BulkConsumer extends _RedisConsumer {
  int consume(List<int> data, final int start, final int end) {
    assert(start < end);

    int current = start;
    if(_lengthRequired == null) {
      current = _lineConsumer.consume(data, current, end);
      if(_lineConsumer.done) {
        final specifiedLength =
          int.parse(new String.fromCharCodes(_lineConsumer.data));
        if(specifiedLength == -1) {
          _lengthRequired = 0;
        } else {
          _lengthRequired = 2 + specifiedLength;
        }
      }
    } else {
      final needed = _lengthRequired - _lengthRead;
      final desiredEnd = start + needed;
      final takeTo = min(desiredEnd, end);
      _dataBlocks.add(new UnmodifiableListView(data.getRange(start, takeTo)));
      _addToLength(takeTo - start);
      current = takeTo;
    }

    if(current < end && !done) {
      current = consume(data, current, end);
    }

    // we've advanced and either are done or ran out
    assert(current > start && (done || current == end));

    return current;
  }

  get done => _lengthRead == _lengthRequired;

  RedisReply makeReply() => new BulkReply(data);

  _addToLength(int additional) {
    _lengthRead += additional;
    assert(_lengthRead <= _lengthRequired);
  }

  _LineConsumer _lineConsumer = new _IntegerConsumer();
  int _lengthRead = 0;
  int _lengthRequired;
}


class _StatusConsumer extends _LineConsumer {
  RedisReply makeReply() => new StatusReply(line);
}

class _ErrorConsumer extends _LineConsumer {
  RedisReply makeReply() => new ErrorReply(line);
}

class _IntegerConsumer extends _LineConsumer {
  RedisReply makeReply() => new IntegerReply(int.parse(line));
}

class _MultiBulkConsumer extends _RedisConsumer {

  int consume(List<int> data, final int start, final int end) {
    assert(start < end);

    int current = start;
    if(_replies == null) {
      current = _lineConsumer.consume(data, current, end);
      if(_lineConsumer.done) {
        final numReplies =
          int.parse(new String.fromCharCodes(_lineConsumer.data));
        _replies = new List<RedisReply>(numReplies);
      }
    } else {
      if(_activeConsumer == null) {
        _activeConsumer = _makeRedisConsumer(data[current++]);
      }
      if(current < end) {
        current = _activeConsumer.consume(data, current, end);
        if(_activeConsumer.done) {
          _replies[_repliesReceived++] = _activeConsumer.makeReply();
          _activeConsumer = null;
        }
      }
    }

    if(current < end && !done) {
      current = consume(data, current, end);
    }

    // we've advanced and either are done or ran out
    assert(current > start && (done || current == end));
    return current;
  }

  RedisReply makeReply() => new MultiBulkReply(_replies);

  /// Consumer is done when all replies have been received
  bool get done => _replies != null && _replies.length == _repliesReceived;

  /// Consumer used to get the number of replies in the MultiBulkReply
  _LineConsumer _lineConsumer = new _IntegerConsumer();

  /// Consumer for the current reply being processed
  _RedisConsumer _activeConsumer;

  /// List of resulting replies in this MultiBulkReply
  List<RedisReply> _replies;

  int _repliesReceived = 0;
}

_RedisConsumer _makeRedisConsumer(final int replyType) {
  switch(replyType) {
    case _STATUS: return new _StatusConsumer();
    case _ERROR: return new _ErrorConsumer();
    case _INTEGER: return new _IntegerConsumer();
    case _BULK: return new _BulkConsumer();
    case _MULTI_BULK: return new _MultiBulkConsumer();
    default: throw new InvalidRedisResponseError(
      "The type character was incorrect (${new String.fromCharCode(replyType)}).");
  }
}

class RedisStreamTransformerHandler {

  StreamTransformer createTransformer() =>
    new StreamTransformer.fromHandlers(handleData: handleData,
        handleError: handleError, handleDone: handleDone);

  void handleDone(EventSink<RedisReply> output) {

    if (_consumer != null) {
      var error = new UnexpectedRedisClosureError("Some data has already been sent but was not complete.");
      // Apparently some data has already been sent, but the stream is done.
      handleError(error, error.stackTrace, output);
    }

    output.close();
  }

  void handleError(Object error, StackTrace stackTrace, EventSink<RedisReply> sink) {
    sink.addError(error, stackTrace);
  }

  void handleData(List<int> data, EventSink<RedisReply> output) {
    // I'm not entirely sure this is necessary, but better be safe.
    if (data.length == 0) return;

    final int end = data.length;
    var i = 0;
    while(i < end) {
      if(_consumer == null) {
        try {
          _consumer = _makeRedisConsumer(data[i++]);
        }
        on RedisProtocolTransformerException catch (e) {
          handleError(e, e.stackTrace, output);
        }
      } else {
        i = _consumer.consume(data, i, end);
        if(_consumer.done) {
          output.add(_consumer.makeReply());
          _consumer = null;
        }
      }
    }
  }

  /// The current consumer
  _RedisConsumer _consumer;
}