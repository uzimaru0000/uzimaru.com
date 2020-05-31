module Command.WhoAmI exposing (..)

import Parser exposing (Parser)
import Utils


type WhoAmI
    = WhoAmI


parser : Parser WhoAmI
parser =
    Utils.iToken "whoami"
        |> Parser.map (always WhoAmI)
