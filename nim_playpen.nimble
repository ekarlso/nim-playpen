[Package]
name          = "nim_playpen"
version       = "0.1.0"
author        = "Endre Karlson"
description   = "Play for nim-lang"
license       = "MIT"

bin = "nim_playpen"
srcDir = "src"

[Deps]
Requires: "nim >= 0.10.2"
Requires: "docopt"
Requires: "jester"
Requires: "uuid"
