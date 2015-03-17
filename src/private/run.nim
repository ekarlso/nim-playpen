import asyncdispatch, future, json, os, osproc, re, sequtils, streams, strutils
import uuid

import opts

type
  Run = ref RunObj
  RunObj* = object
    id*: string
    input*: string
    output*: seq[string]
    error*: string
    code: int
    version*: string
    compilerOptions*: seq[string]
    executeRun*: bool

  InvalidRun = object of Exception


proc `%`*(run: Run): JsonNode =
  result = %{
    "id": %run.id,
    "input": %run.input,
    "compilerOptions": %run.compilerOptions.map((s: string) => (%s)),
    "run": %run.executeRun
  }

  if run.output != nil:
    result["output"] = %run.output.map((s: string) => (%s))
  else:
    result["output"] = newJNull()

  result["error"] = if run.error != nil: %run.error else: newJNull()

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

  if node.hasKey("run") and node["run"].kind == JBool:
    result.executeRun = node["run"].bval
  else:
    result.executeRun = true

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

# Return the path of the run
proc runDir*(run: Run): string =
  result = joinPath("/mnt/runs/", run.id.replace("-", "_"))

proc runFile*(run: Run): string =
  result = joinPath(run.runDir, "file.nim")

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
    "-b" & run.runDir,
    "--"
  ]

proc runCmd(run: Run): seq[string] =
  result = @[
    "/usr/local/bin/eval.sh", run.version, run.runDir
  ]

proc writeRunOpts(run: Run) =
  var opts = @[
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

  opts.add(run.compilerOptions)

  opts.add("compile")
  if run.executeRun:
    opts.add("--run")

  writeFile(joinPath(run.runDir, "options"), join(opts, " "))

proc killIt*(pid: int) =
  let cmd = @[findExe"sudo", "kill", "-9", $pid]
  discard execCmdEx(join(cmd, " "))

proc execute*(self: Run, options: Opts) {.async.} =
  let
    chrootPath = joinPath(self.chrootPath(options), self.runDir)

  echo ("Creating directory: " & chrootPath)
  createDir(chrootPath)

  echo ("Creating directory: " & self.runDir)
  createDir(self.runDir)

  writeFile(self.runFile, self.input)
  echo("Snippet written to: " & self.runFile)

  self.writeRunOpts

  var cmd = self.playpenCmd(options)

  cmd.add(self.runCmd)

  echo ("Calling: " & join(cmd, " "))
  let process = startProcess(findExe("sudo"), args = cmd)

  while true:
    if process.running:
      var processes = @[process]
      let readable: int = select(processes, 1)

      if readable == 1:
        if self.output.len > 10000:
          self.error = "Request $# got too large output" % self.id
          break

        let line = process.outputStream.readLine()
        self.output.add($line)
      else:
        await sleepAsync(50)
    else:
      break

  self.code = process.peekExitCode
  if self.error == nil:
    self.error = process.errorStream.readLine
  if process != nil:
    process.close()