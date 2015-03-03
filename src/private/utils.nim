import json, strutils

type
  KeyError* = object of Exception

proc checkKeys*(node: JsonNode, keys: varargs[string]) =
  for k in keys:
    if not node.hasKey(k):
      raise newException(KeyError, "Missing key $#" % k)
