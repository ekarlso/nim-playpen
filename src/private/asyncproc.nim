import osproc, asyncdispatch, streams, strtabs

## Output format.
## --------------
##
## /curr/dir $ command --args
## Stdout output
## ! stderr output

type
  AsyncExecutor* = ref object
    threads: array[1024, TThread[int]]
    busyThreads: set[0 .. 1023]
    startedThreads: set[0 .. 1023]

  ProgressCB* = proc (message: ProcessEvent): Future[void] {.closure, gcsafe.}

  ThreadCommandKind = enum
    StartProcess, KillProcess

  ThreadCommand = object
    case kind: ThreadCommandKind
    of StartProcess:
      command: string
      workingDir: string
      args: seq[string]
      env: StringTableRef
    of KillProcess: nil

  ProcessEventKind* = enum
    ProcessStdout, ProcessStderr, ProcessEnd, CommandError, ThreadError

  ProcessEvent* = object
    threadId*: int
    case kind*: ProcessEventKind
    of ProcessStdout, ProcessStderr:
      data*: string
    of ProcessEnd:
      code*: int
    of CommandError, ThreadError:
      error: string

  AsyncExecutorError = object of Exception

var commandChans: array[1024, TChannel[ThreadCommand]]
for i in 0..1023:
  commandChans[i].open()

var messageChans: array[1024, TChannel[ProcessEvent]]
for i in 0..1023:
  messageChans[i].open()

proc newAsyncExecutor*(): AsyncExecutor =
  new result

proc executorThread(threadId: int) {.thread, raises: [DeadThreadError, Exception].} =
  try:
    var process: Process = nil
    var line = ""
    while true:
      # Check command channel.
      let (received, command) =
        if process != nil: commandChans[threadId].tryRecv()
        else: (true, commandChans[threadId].recv())
      if received:
        case command.kind
        of StartProcess:
          try:
            process = startProcess(command.command, command.workingDir,
                                   command.args, command.env)
            echo "Started PID: " & $process.processID
          except:
            let error = "Unable to launch process: " & getCurrentExceptionMsg()
            messageChans[threadId].send(ProcessEvent(kind: CommandError, error: error, threadId: threadId))
        of KillProcess:
          if process == nil:
            let error = "No process to kill."
            messageChans[threadId].send(ProcessEvent(kind: CommandError, error: error, threadId: threadId))
          else:
            echo ("Killing PID: " & $process.processID)
            process.kill()

      if process != nil:
        line = ""
        # Check process' output streams.
        if process.outputStream.readLine(line):
          messageChans[threadId].send(ProcessEvent(kind: ProcessStdout, data: line, threadId: threadId))
        # Check if the process finished.
        if process.peekExitCode() != -1:
          # First read all the output.
          while true:
            if process.outputStream.readLine(line):
              messageChans[threadId].send(ProcessEvent(kind: ProcessStdout, data: line, threadId: threadId))
            else:
              break
          # Then close the process.
          messageChans[threadId].send(
              ProcessEvent(kind: ProcessEnd, code: process.peekExitCode(), threadId: threadId))
          process.close()
          process = nil
  except:
    let error = "Unhandled exception in thread: " & getCurrentExceptionMsg()
    messageChans[threadId].send(ProcessEvent(kind: ThreadError, error: error))

#proc start*(self: AsyncExecutor) =
#  ## Starts the AsyncExecutor's underlying thread.
#  createThread[void](self.thread, executorThread)

proc getThreadId*(self: AsyncExecutor): int =
  for i in 0 .. 1023:
    if i notin self.busyThreads:
      return i

proc killProcess*(threadId: int) =
  let cmd = ThreadCommand(kind: KillProcess)
  commandChans[threadId].send(cmd)

proc exec*(self: AsyncExecutor, threadId: int,
           command: string, progress: ProgressCB,
           workingDir = "", args: seq[string] = @[],
           env: StringTableRef = nil) {.async.} =
  ## Executes ``command`` asynchronously. Completes returned Future once
  ## the executed command finishes execution.

  assert(threadId notin self.busyThreads)

  if threadId notin self.startedThreads:
    createThread[int](self.threads[threadId], executorThread, threadId)
    self.startedThreads.incl(threadId)

  # Start the process.
  commandChans[threadId].send(
      ThreadCommand(kind: StartProcess, command: command,
                    workingDir: workingDir, args: args, env: env))

  self.busyThreads.incl(threadId)

  # Check every second for messages from the thread.
  while true:
    while true:
      let (received, msg) = messageChans[threadId].tryRecv()
      if received:
        case msg.kind
        of ProcessStdout, ProcessStderr, ProcessEnd:
          asyncCheck progress(msg)
          if msg.kind == ProcessEnd:
            self.busyThreads.excl(threadId)
            return
        of CommandError:
          self.busyThreads.excl(threadId)
          raise newException(AsyncExecutorError, msg.error)
        of ThreadError:
          #self.startedThreads.del(threadId)
          self.busyThreads.excl(threadId)
          raise newException(AsyncExecutorError, msg.error)
      else:
        break

    await sleepAsync(50)

when isMainModule:
  import os
  var executor = newAsyncExecutor()
  #executor.start()
  proc onProgress(event: ProcessEvent) {.async.} =
    echo(event.repr)

  var thrId = getThreadId(executor)
  waitFor executor.exec(thrId, findExe"nim", onProgress, getCurrentDir() / "tests",
                        @["c", "hello.nim"])