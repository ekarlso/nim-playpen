import asyncdispatch, json, os, strutils
import uuid

import asyncproc

type
  RunResult* = enum
    Success = 0, Error = 1

  Run = ref RunObj
  RunObj* = object
    id*: string
    input*: string
    output*: string
    result*: RunResult
    code: int
    version*: string
    compilerOptions: JsonNode

var defaultOpts = %{
  "threads": %false,
  "stackTrace": %false,
  "checks": %true
}

var executor = newAsyncExecutor()

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

proc playpenCmd(binPath: string, chrootPath: string): seq[string] =
  result = @[
    findExe"sudo",
    binPath,
    chrootPath,
    "--mount-proc",
    "--user=nim",
    "--timeout=5",
    "--syscalls-file=whitelist",
    "--devices=/dev/urandom:r,/dev/null:w",
    "--memory-limit=128",
    "--"
  ]

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

  #let opts = run.compilerOptions.toArgs
  #echo "Compiler options for " & run.id & ": " & $opts

  #args.add(opts)

  args.add(@[
    "compile",
    "--run",
    runFile
  ])

  #var foo = runInPen(playPath, chrootPath, cmd = args)

  #if output.len > 1000:
  #  run.result = Error
  ##  run.output = "Output too long..."
  #else:
  #  run.output = output
  #  if code.int != 0:
  #    run.result = Error

proc execute*(self: Run, playPath: string, versionsPath: string) {.async.} =
  self.output = ""

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
    chrootPath = joinPath(versionsPath, self.version)
    runDir = joinPath("/", "mnt", "runs", self.id.replace("-", "_"))
    runFile = joinPath(runDir, "file.nim")
    nimPath = joinPath("/usr/local/nim/versions", self.version, "bin", "nim")

  echo "chroot " & chrootPath
  let path = joinPath(chrootPath, runDir)
  echo ("Creating directory: " & path)
  createDir(path)

  echo "Writing snippet"
  writeFile(joinPath(chrootPath, runFile), self.input)
  echo("Snippet written to: " & runFile)

  var cmd = playpencmd(playPath, chrootPath)
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

  let opts = self.compilerOptions.toArgs
  echo "Compiler options for " & self.id & ": " & $opts

  cmd.add(opts)

  cmd.add(@[
    "compile",
    "--run",
    runFile
  ])

  echo ("Calling: " & join(cmd, " "))
  executor.start()
  await executor.exec(findExe("sudo"), progress = cb, args = cmd)