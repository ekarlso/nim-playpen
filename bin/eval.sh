#!/bin/bash

VERSION="$1"
RUN_DIR="$2"

NIM_BIN="/usr/local/nim/versions/$VERSION/bin/nim"
NIM_OPTS="$(cat $RUN_DIR/options)"
NIM_FILE="$RUN_DIR/file.nim"

$NIM_BIN $NIM_OPTS $NIM_FILE
