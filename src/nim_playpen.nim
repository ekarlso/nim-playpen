import asyncdispatch, docopt, future, jester, json, os, strutils

import private/playpen, private/run, private/utils

const
    VERSION = "0.0.1"
    JSON = "application/json"


let doc = """
Play pen for nim-lang a'la play.rust-lang.org.

Usage:
    nim_playpen [-c FILE]

    -c          JSON config file [default: ./nim-playpen.json]

Options:
    -h, --help  Help message
"""

let args = docopt(doc, version="nim-playpen " & VERSION)

var
  cfg: JsonNode
  cfgFile: string

if args["-c"]:
  cfgFile = $args["FILE"]
else:
  cfgFile = getCurrentDir() & "/nim_playpen.json"

if not existsFile(cfgFile):
  quit("Config file $# not found... exiting." % cfgFile)

echo("Reading config...")

let cfgContents = readFile(cfgFile)
cfg = parseJson(cfgContents)


var
    port = if cfg.hasKey("port") and cfg["port"].kind == JInt: cfg["port"].num else: 5000
    staticDir =  if cfg.hasKey("static_dir"): cfg["static_dir"].str else: getCurrentDir() & "/static"
    settings = newSettings(port = Port(port), staticDir = staticDir)

routes:
    post "/runs":
        let node = parseJson($request.body)

        var e: string
        try:
           utils.checkKeys(node, "input")
        except utils.KeyError:
            e = getCurrentExceptionMsg()
        if e != nil:
            halt(Http400, e)

        var snippetRun = node.toRun

        await execute(snippetRun, cfg["playpenPath"].str, cfg["versionsPath"].str)

        let runJson = %snippetRun
        resp(Http200, $runJson)

    get "/version":
        let version = %{"version": %VERSION}
        resp(Http200, $version)

    get "/versions":
        resp($cfg["versions"], JSON)

runForever()
