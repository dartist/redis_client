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



  /// Closes the connection.
  Future close();


  Map get stats;


  Future select([ int db ]);

  /// Convenient method to send [String] commands.
  Receiver send(List<String> cmdWithArgs);

  /// Sends the commands already in binary.
  Receiver rawSend(List<List<int>> cmdWithArgs);

//
//  Future<String> sendExpectCode(List<List> cmdWithArgs);
//
//  Future<Object> sendExpectSuccess(List<List> cmdWithArgs);
//
//  Future<int> sendExpectInt(List<List> cmdWithArgs);
//
//  Future<bool> sendExpectIntSuccess(List<List> cmdWithArgs);
//
//  Future<List<int>> sendExpectData(List<List> cmdWithArgs);
//
//  Future<List<List<int>>> sendExpectMultiData(List<List> cmdWithArgs);
//
//  Future<String> sendExpectString(List<List> cmdWithArgs);
//
//  Future<double> sendExpectDouble(List<List> cmdWithArgs);


}


/// The actual implementation of the [RedisConnection].
class _RedisConnection implements RedisConnection {


  // Connection settings

  final String connectionString;

  final String hostname;

  final String password;

  final int port;

  int db;


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
  const List<int> _lineEnd = const [ 13, 10 ];


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
              .transform(new RedisProtocolTransformer())
              .listen(_onRedisReply, onError: _onStreamError, onDone: _onStreamDone);

          if (password != null) return _authenticate();
        })
        .then((_) {
          if (db > 0) return select();
        })
        // The RedisConnection has connected successfully.

        .catchError(_onSocketError);

  }


  /// Closes the connection.
  Future close() => _socket.close();


  /// Selects configured database.
  ///
  /// If db is provided the configuration [db] will be set to it.
  Future select([ int db ]) {
    if (db != null) this.db = db;
    return send([ "SELECT", db.toString() ]).receive();
  }

  /// Authenticates with configured password.
  Future _authenticate(String _password) => sendExpectSuccess([ "AUTH", password ]);



  /// Gets called when the socket has an error.
  void _onSocketError(err) {
    logger.warning("Socket error $err.");
    throw new RedisClientException("Socket error $err.");
  }

  /// Handles new data received from stream.
  void _onRedisReply(RedisReply redisReply) {
    // processSocketData("onSocketData");
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
  Receiver send(List<String> cmdWithArgs) => rawSend(cmdWithArgs.map((String line) => encodeUtf8(line)).toList(growable: false));


  /**
   * This is the same as [send] except that it takes a list of binary data.
   *
   * Eg.:
   *
   *     rawSend([ "GET".codeUnits, encodeUtf8("keyname") ]).receiveBulkString().then((String value) { });
   */
  Receiver rawSend(List<List<int>> cmdWithArgs) {
    var response = new Receiver();

    logger.finest("Sending message $cmdWithArgs");

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
  Future receive() => _received;

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
   * Checks that the received reply is of type [StatusReply].
   */
  Future<String> receiveStatus([ String expectedStatus ]) {
    return _received.then((reply) {
      if (reply is! StatusReply) {
        throw new RedisClientException("The returned reply was not of type StatusReply.");
      }
      if (?expectedStatus && (expectedStatus != reply.status)) {
        throw new RedisClientException("The returned status was not $expectedStatus but ${reply.status}.");
      }
      return reply.status;
    });
  }

  /**
   * Checks that the received reply is of type [BulkReply] and returns the byte
   * list.
   */
  Future<RedisReply> receiveBulkData() {
    return _received.then((reply) {
      if (reply is! BulkReply) {
        throw new RedisClientException("The returned reply was not of type BulkReply.");
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
        throw new RedisClientException("The returned reply was not of type BulkReply.");
      }
      return reply.string;
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

