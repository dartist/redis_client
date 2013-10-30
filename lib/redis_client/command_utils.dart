part of redis_client;


class _CommandUtils {

  static List<List<int>> mergeCommandWithKeysAndValues(List<int> cmd, List<List<int>> keys, List<List<int>> values) =>
    mergeParamsWithKeysAndValues([cmd], keys, values);

  static List<List<int>> mergeParamsWithKeysAndValues(List<List<int>> firstParams, List<List<int>> keys, List<List<int>> values) {
    if (keys == null || keys.length == 0) {
      throw new Exception("keys is null");
    }
    if (values == null || values.length == 0) {
      throw new Exception("values is null");
    }
    if (keys.length != values.length) {
      throw new Exception("keys.length != values.length");
    }

    int keyValueStartIndex = firstParams != null ? firstParams.length : 0;

    int keysAndValuesLength = keys.length * 2 + keyValueStartIndex;
    List<List<int>> keysAndValues = new List<List<int>>();

    for (int i = 0; i < keyValueStartIndex; i++){
      keysAndValues.add(firstParams[i]);
    }

    int j = 0;
    for (int i = keyValueStartIndex; i < keysAndValuesLength; i += 2){
      keysAndValues.add(keys[j]);
      keysAndValues.add(values[j]);
      j++;
    }
    return keysAndValues;
  }

  /// Returns a single list with the command and the arguments as bytes merged into one.
  static List<List<int>> mergeCommandWithStringArgs(List<int> cmd, List<String> args) =>
    mergeCommandWithArgs(cmd, args.map((x) => UTF8.encode(x)).toList(growable: false));

  /// Returns a single list with the command, the key and the arguments as bytes merged into one.
  static List<List<int>> mergeCommandWithKeyAndStringArgs(List<int> cmd, String key, List<String> args){
    args.insert(0, key);
    return mergeCommandWithArgs(cmd, args.map((x) => UTF8.encode(x)).toList(growable: false));
  }

  static List<List<int>> mergeCommandWithKeyAndArgs(List<int> cmd, String key, List<List<int>> args){
    args.insert(0, key.runes.toList());
    return mergeCommandWithArgs(cmd, args);
  }


  static List<List<int>> mergeCommandWithArgs(List<int> cmd, List<List<int>> args){
    List<List<int>> mergedBytes = new List<List<int>>(args.length + 1);
    mergedBytes[0] = cmd;
    for (var i = 0; i < args.length; i++){
      mergedBytes[i + 1] = args[i];
    }
    return mergedBytes;
  }


}