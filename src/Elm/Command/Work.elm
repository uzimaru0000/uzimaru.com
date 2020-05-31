module Command.Work exposing (..)

import Parser exposing ((|.), (|=), Parser)
import Utils


type Work
    = Work Args


type alias Args =
    { yes : Bool
    , param : Maybe String
    }


parser : Parser Work
parser =
    Parser.succeed (\_ -> Work)
        |= Utils.iToken "work"
        |. Parser.spaces
        |= argsParser { yes = False, param = Nothing }


argsParser : Args -> Parser Args
argsParser =
    Utils.argsParser <|
        \default ->
            Parser.oneOf
                [ Parser.succeed (\_ -> { default | yes = True })
                    |= Utils.optionParser "y" "yes"
                    |. Parser.spaces
                , Parser.succeed (\str -> { default | param = Just str })
                    |= Utils.anyString
                    |. Parser.spaces
                ]
