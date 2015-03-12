import json, net, os

import jester

type
  Opts* = ref OptsObj

  OptsObj* = object
    playpenPath*: string
    versionsPath*: string

    jesterSettings*: Settings


proc newJesterSettings*(node: JsonNode): Settings =
  let
    port = if node.hasKey("port") and node["port"].kind == JInt: node["port"].num else: 8080
    staticDir =  if node.hasKey("static_dir"): node["static_dir"].str else: getCurrentDir() & "/static"
  result = newSettings(port = Port(port), staticDir = staticDir)


# Get options from a JsonNode
proc newOptsFromJObject*(node: JsonNode): Opts =
  new result
  if node.hasKey("playpenPath"):
    result.playpenPath = node["playpenPath"].str
  if node.hasKey("versionsPath"):
    result.versionsPath = node["versionsPath"].str

  result.jesterSettings = node.newJesterSettings


# Read options from a json file
proc newOptsFromFile*(file: string): Opts =
  let
    contents = readFile(file)
    node = parseJson(contents)
  result = newOptsFromJObject(node)