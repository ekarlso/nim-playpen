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
    snippetDir: string

proc `%`*(runResult: RunResult): JsonNode =
  %($runResult)

proc `%`*(run: Run): JsonNode =
  result = %{
    "input": %run.input,
    "result": %run.result
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
    "/usr/local/bin/eval.sh",
    nimPath,
    "--nimcache:/tmp",
    #"--out:" & joinPath(runDir, "program"),
    "--stackTrace:off",
    "--lineTrace:off",
    "--threads:off",
    "--checks:off",
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
    "--cc:ucc",
    "compile",
    "--run",
    runFile
  ]

  let
    (output, code) = runInPen(playPath, chrootPath, cmd = args)

  run.output = output
  if code.int != 0:
    run.result = Error
