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
  
  var isConnected = false;
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

  /// Handlers for stream transformation from stream of int to stream of RedisReply
  RedisStreamTransformerHandler _streamTransformerHandler = new RedisStreamTransformerHandler();

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

          isConnected = true;

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
    isConnected = false;
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
    close();
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

    assert(!_pendingResponses.isEmpty);

    final pending = _pendingResponses.removeFirst();
    assert(pending.reply == null);
    pending.reply = redisReply;
  }

  /// Handles stream errors
  void _onStreamError(err) {
    logger.warning("Stream error $err");
    _socket.close();
    isConnected = false;
    throw new RedisClientException("Received stream error $err.");
  }

  /// Gets called when the stream closes.
  void _onStreamDone() {
    isConnected = false;
    logger.fine("Stream finished.");
  }


  Queue<Receiver> _pendingResponses = new Queue<Receiver>();

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
    
    if (!isConnected)
      throw new RedisClientException('redis socket not connected');

    var response = new Receiver();
    
   
    if( logger.level <= Level.FINEST){
      logger.finest("Sending message ${UTF8.decode(cmdWithArgs[0])}");
    }
    
    //we call _socket.add only once and we try to avoid string concat
    List<int> buffer = new List<int>();
    buffer.addAll("*".codeUnits);
    buffer.addAll(cmdWithArgs.length.toString().codeUnits);
    buffer.addAll(_lineEnd);    
    for( var line in cmdWithArgs) {
      buffer.addAll("\$".codeUnits);
      buffer.addAll(line.length.toString().codeUnits);
      buffer.addAll(_lineEnd);
      buffer.addAll(line);
      buffer.addAll(_lineEnd);
    }
    _socket.add(buffer);
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
