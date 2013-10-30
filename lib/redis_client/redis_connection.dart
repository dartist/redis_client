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

  

  void handleDone(EventSink<RedisReply> output);
  
  void handleError(Object error, StackTrace stackTrace, EventSink<RedisReply> sink);
  
  void handleData(List<int> data, EventSink<RedisReply> output);

  /// Closes the connection.
  Future close();


  Map get stats;


  Future select([ int db ]);

  /// Convenient method to send [String] commands.
  Receiver send(List<String> cmdWithArgs);

  /// Convenient method to send a command with a list of [String] arguments.
  Receiver sendCommand(List<int> command, List<String> args);

  /// Sends the commands already in binary.
  Receiver rawSend(List<List<int>> cmdWithArgs);


}


/// The actual implementation of the [RedisConnection].
class _RedisConnection extends RedisConnection {


  // Connection settings

  final String connectionString;

  final String hostname;

  final String password;

  final int port;

  int db;
  

  RedisReply _currentReply;

  void handleDone(EventSink<RedisReply> output) {

    if (_currentReply != null) {
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
  
    if (_currentReply == null) {
      // This is a fresh RedisReply. How exciting!
  
      try {
        _currentReply = new RedisReply.fromType(data.first);
      }
      on RedisProtocolTransformerException catch (e) {
        handleError(e, e.stackTrace, output);
      }
    }
  
    List<int> unconsumedData = _currentReply.consumeData(data);
  
    // Make sure that unconsumedData can't be returned unless the reply is actually done.
    assert(unconsumedData == null || _currentReply.done);
  
    if (_currentReply.done) {
      // Reply is done!
      output.add(_currentReply);
      _currentReply = null;
      if (unconsumedData != null && !unconsumedData.isEmpty) {
        handleData(unconsumedData, output);
      }
    }
  }
  
  /// The [Socket] used in this connection.
  Socket _socket;


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
          
          // Setting up all the listeners so Redis responses can be interpreted.
          socket
              .transform(new StreamTransformer.fromHandlers(handleData: handleData, handleError: handleError, handleDone: handleDone))
              .listen(_onRedisReply, onError: _onStreamError, onDone: _onStreamDone);

          if (password != null) return _authenticate(password);
        })
        .then((_) {
          if (db > 0) return select();
        })
        // The RedisConnection has connected successfully.

        .catchError(_onSocketError);

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

  /// Handles new data received from stream.
  void _onRedisReply(RedisReply redisReply) {
    logger.fine("Received reply: $redisReply");
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

    connected.then((_) {
      _socket.add("*${cmdWithArgs.length}\r\n".codeUnits);
      cmdWithArgs.forEach((line) {
        _socket.add("\$${line.length}\r\n".codeUnits);

        // Write the line, and the line end
        _socket.add(line);
        _socket.add(_lineEnd);
      });
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
        throw new RedisClientException("The returned reply was not of type IntegerReply.");
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
        throw new RedisClientException("The returned reply was not of type ErrorReply.");
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
        throw new RedisClientException("The returned reply was not of type BulkReply but ${reply.runtimeType}.");
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
        throw new RedisClientException("The returned reply was not of type BulkReply but ${reply.runtimeType}.");
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
        throw new RedisClientException("The returned reply was not of type MultiBulkReply but ${reply.runtimeType}.");
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
      return reply.replies.map((BulkReply reply) => serializer.deserialize(reply.bytes)).toList(growable: false);
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


