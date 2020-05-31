module Command.Link exposing
    ( Args
    , Link(..)
    , parser
    )

import Parser exposing ((|.), (|=), Parser)
import Utils


type Link
    = Link Args


type alias Args =
    { yes : Bool
    , param : Maybe String
    }


parser : Parser Link
parser =
    Parser.succeed Link
        |. Utils.iToken "link"
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
