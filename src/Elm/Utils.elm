module Utils exposing
    ( anyString
    , argsParser
    , iToken
    , optionParser
    )

import Parser exposing ((|.), Parser)
import Set


iToken : String -> Parser ()
iToken token =
    Parser.backtrackable (Parser.loop token iTokenHelp)


iTokenHelp : String -> Parser (Parser.Step String ())
iTokenHelp chars =
    case String.uncons chars of
        Just ( char, remainingChars ) ->
            Parser.oneOf
                [ Parser.succeed (Parser.Loop remainingChars)
                    |. Parser.chompIf (\c -> Char.toLower c == char)
                , Parser.problem ("Expected case insensitive \"" ++ chars ++ "\"")
                ]

        Nothing ->
            Parser.succeed <| Parser.Done ()


anyString : Parser String
anyString =
    Parser.variable
        { start = \_ -> True
        , inner = \c -> c /= ' '
        , reserved = Set.fromList []
        }


argsParser : (a -> Parser a) -> a -> Parser a
argsParser argParser default =
    Parser.loop default <|
        \args ->
            Parser.oneOf
                [ argParser args |> Parser.map Parser.Loop
                , Parser.end |> Parser.map (\_ -> Parser.Done args)
                ]


optionParser : String -> String -> Parser ()
optionParser shortOpt longOpt =
    Parser.oneOf
        [ longOptionParser longOpt
        , shortOptionParser shortOpt
        ]


shortOptionParser : String -> Parser ()
shortOptionParser opt =
    Parser.succeed ()
        |. Parser.symbol "-"
        |. Parser.keyword opt


longOptionParser : String -> Parser ()
longOptionParser opt =
    Parser.succeed ()
        |. Parser.symbol "--"
        |. Parser.keyword opt
