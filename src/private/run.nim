import asyncdispatch, future, json, os, re, sequtils, strutils
import uuid

import asyncproc, opts

type
  RunResult* = enum
    Success = 0, Error = 1

  Run = ref RunObj
  RunObj* = object
    id*: string
    input*: string
    output*: seq[string]
    result*: RunResult
    code: int
    version*: string
    compilerOptions: seq[string]

  InvalidRun = object of Exception

var executor = newAsyncExecutor()


proc `%`*(runResult: RunResult): JsonNode =
  %($runResult)

proc `%`*(run: Run): JsonNode =
  result = %{
    "id": %run.id,
    "input": %run.input,
    "result": %run.result,
    "compilerOptions": %run.compilerOptions.map((s: string) => (%s))
  }

  if run.output != nil:
    result["output"] = %run.output.map((s: string) => (%s))
  else:
    result["output"] = newJNull()

proc newRun(): Run =
  var
    id: Tuuid
  result = Run()
  uuid.uuid_generate_random(id)
  result.id = $id.toHex()
  result.output = newSeq[string]()

proc toRun*(node: JsonNode): Run =
  result = newRun()

  result.input = node["input"].str
  result.version = node["version"].str

  var runOpts = newJArray()

  if node.hasKey("compilerOptions"):
    if node["compilerOptions"].kind != JArray:
      raise newException(InvalidRun, "Errorous run options, needs to be a array.")

    runOpts = node["compilerOptions"]

  var strOpts = newSeq[string]()
  for o in runOpts:
    if o.str =~ re"^\-{1,2}[A-Za-z0-9]+([:=]|)([A-Za-z0-9]+|)$":
      strOpts.add(o.str)
    else:
      raise newException(InvalidRun, "Invalid option $#" % o.str)
  result.compilerOptions = strOpts

proc chrootPath*(run: Run, opts: Opts): string =
  result = joinPath(opts.versionsPath, run.version)

proc playpenCmd*(run: Run, opts: Opts): seq[string] =
  result = @[
    findExe"sudo",
    opts.playpenPath,
    run.chrootPath(opts),
    "--mount-proc",
    "--user=nim",
    "--timeout=5",
    "--syscalls-file=whitelist",
    "--devices=/dev/urandom:r,/dev/null:w",
    "--memory-limit=128",
    "--"
  ]

proc execute*(self: Run, options: Opts) {.async.} =
  proc cb(event: ProcessEvent) {.async.} =
    # Do necassary actions based on event kind.
    case event.kind:
      of ProcessStdout, ProcessStderr:
        self.output.add(event.data)
      of ProcessEnd:
        self.code = event.code
        self.result = if event.code == 0: Success else: Error

      else: discard

  let
    runDir = joinPath("/", "mnt", "runs", self.id.replace("-", "_"))
    runFile = joinPath(runDir, "file.nim")
    nimPath = joinPath("/usr/local/nim/versions", self.version, "bin", "nim")

  let path = joinPath(self.chrootPath(options), runDir)
  echo ("Creating directory: " & path)
  createDir(path)

  echo "Writing snippet"
  writeFile(joinPath(self.chrootPath(options), runFile), self.input)
  echo("Snippet written to: " & runFile)

  var cmd = self.playpenCmd(options)

  cmd.add(@[
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
  ])

  let compilerOptions = self.compilerOptions
  echo "Compiler options for " & self.id & ": " & $compilerOptions

  cmd.add(compilerOptions)

  cmd.add(@[
    "compile",
    "--run",
    runFile
  ])

  echo ("Calling: " & join(cmd, " "))
  executor.start()
  await executor.exec(findExe("sudo"), progress = cb, args = cmd)
