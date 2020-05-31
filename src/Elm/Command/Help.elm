module Command.Help exposing
    ( Args
    , Help(..)
    , help
    , parser
    )

import Html exposing (Html)
import Parser exposing ((|.), (|=), Parser)
import Utils


type Help cmd
    = Help (Args cmd)


type alias Args cmd =
    { command : Maybe cmd }


parser : (String -> Maybe cmd) -> Parser (Help cmd)
parser fn =
    Parser.succeed Help
        |. Utils.iToken "help"
        |. Parser.spaces
        |= argsParser fn { command = Nothing }


argsParser : (String -> Maybe cmd) -> Args cmd -> Parser (Args cmd)
argsParser fn =
    Utils.argsParser <|
        \default ->
            Parser.oneOf
                [ Parser.succeed (\str -> { default | command = (String.toLower >> fn) str })
                    |= Utils.anyString
                    |. Parser.spaces
                ]


help : Html msg
help =
    Html.div []
        [ Html.text "this is HelpCommand help message" ]
