import json, os, strutils
import uuid

import playpen

type
  RunResult* = enum
    Success = 0, Error = 1

  Run* = object
    id*: string
    input*: string
    output*: string
    result*: RunResult
    version*: string
    compilerOptions: JsonNode
    snippetDir: string

var defaultOpts = %{
  "threads": %false,
  "stackTrace": %false,
  "checks": %true
}

proc `%`*(runResult: RunResult): JsonNode =
  %($runResult)


proc `%`*(run: Run): JsonNode =
  result = %{
    "id": %run.id,
    "input": %run.input,
    "result": %run.result,
    "compilerOptions": run.compilerOptions
  }

  if run.output != nil:
    result["output"] = %run.output
  else:
    result["output"] = newJNull()


proc newRun(): Run =
    var
      id: Tuuid
    result = Run()
    uuid.uuid_generate_random(id)
    result.id = $id.toHex()

proc toRun*(node: JsonNode): Run =
  result = newRun()

  result.input = node["input"].str
  result.version = node["version"].str
  if node.hasKey("compilerOptions"):
    result.compilerOptions = node["compilerOptions"]
  else:
    result.compilerOptions = newJObject()

proc toArgs*(compilerOptions: JsonNode): seq[string] =
  var opts = if compilerOptions != nil: compilerOptions else: newJObject()

  echo opts

  for k, v in defaultOpts:
    if not opts.hasKey(k):
      opts[k] = defaultOpts[k]

  result = newSeq[string]()
  for k, v in opts:
    var asString: string
    case v.kind:
      of JBool:
        asString = if v.bval == true: "on" else: "off"
      else:
        asString = v.str

    result.add("--$#:$#" % [k, asString])

proc execRun*(run: var Run, playPath: string, versionsPath: string) =
  let
    chrootPath = joinPath(versionsPath, run.version)
    runDir = joinPath("/", "mnt", "runs", run.id.replace("-", "_"))
    runFile = joinPath(runDir, "file.nim")
    nimPath = joinPath("/usr/local/nim/versions", run.version, "bin", "nim")

  echo "chroot " & chrootPath
  let path = joinPath(chrootPath, runDir)
  echo ("Creating directory: " & path)
  createDir(path)

  echo "Writing snippet"
  writeFile(joinPath(chrootPath, runFile), run.input)
  echo("Snippet written to: " & runFile)

  var args = @[
    nimPath,
    "--nimcache:/tmp", # Same as below
    "-o:/tmp/program", # Store in /tmp since it's in-memory mount by playpen
    "--lineTrace:off",
    "--fieldChecks:off",
    "--rangeChecks:on",
    "--boundChecks:on",
    "--overflowChecks:on",
    "--assertions:on",
    "--floatChecks:off",
    "--nanChecks:on",
    "--infChecks:off",
    "--opt:none",
    "--warnings:off",
    "--hints:off",
    "--threadanalysis:off",
    "--verbosity:0",
    #"--cc:ucc",
  ]

  let opts = run.compilerOptions.toArgs
  echo "Compiler options for " & run.id & ": " & $opts

  args.add(opts)

  args.add(@[
    "compile",
    "--run",
    runFile
  ])

  let
    (output, code) = runInPen(playPath, chrootPath, cmd = args)

  if output.len > 1000:
    run.result = Error
    run.output = "Output too long..."
  else:
    run.output = output
    if code.int != 0:
      run.result = Error
