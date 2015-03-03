import osproc, sets, sequtils, strutils


proc runInPen*(playPath: string, chrootPath: string, cmd: varargs[string]): tuple[output: TaintedString, exitCode: int] =
  var playCmd = @[
    "sudo",
    playPath,
    chrootPath,
    "--mount-proc",
    "--user=nim",
    "--timeout=5",
    "--syscalls-file=whitelist",
    "--devices=/dev/urandom:r,/dev/null:w",
    "--memory-limit=128",
    "--"
  ]

  playCmd.add(@cmd)

  let cmdString = join(playCmd, " ")

  echo ("Running command: " & $cmdString)
  result = execCmdEx(cmdString)