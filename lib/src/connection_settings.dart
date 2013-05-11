part of redis_client;



/// Parses the connection string.
class ConnectionSettings {

  final String connectionString;

  String hostname = "localhost";

  String password;

  int port = 6379;

  int db = 0;

  /// Parses provided connection string and sets the corresponding settings.
  ///
  /// See the [RedisConnection] class documentation on which connectionStrings
  /// are allowed.
  ConnectionSettings(String this.connectionString){
    List<String> parts = connectionString.split("@");

    if (parts.length == 2) password = parts.first;

    parts = parts.last.split(":");
    bool hasPort = parts.length == 2;

    hostname = parts.first;

    if (hasPort) {
      parts = parts.last.split("/");
      port = int.parse(parts.first);
      if (parts.length == 2) db = int.parse(parts.last);
    }
  }

}

