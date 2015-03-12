import asyncdispatch, docopt, future, jester, json, os, strutils

import private/run, private/utils, private/opts

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

var cfgFile: string

if args["-c"]:
  cfgFile = $args["FILE"]
else:
  cfgFile = getCurrentDir() & "/nim_playpen.json"

if not existsFile(cfgFile):
  quit("Config file $# not found... exiting." % cfgFile)

var options = newOptsFromFile(cfgFile)

var
  settings = options.jesterSettings

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

        await execute(snippetRun, options)

        let runJson = %snippetRun
        resp(Http200, $runJson)

    get "/version":
        let version = %{"version": %VERSION}
        resp(Http200, $version)

    get "/versions":
      var versions = newJArray()

      for kind, path in walkDir(options.versionsPath):
        if kind == pcDir:
          let name = extractFilename(path)
          versions.add(%name)
      resp($(%{"default": %"devel", "available": versions}), JSON)

runForever()
