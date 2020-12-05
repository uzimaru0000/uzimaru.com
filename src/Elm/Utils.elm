module Utils exposing
    ( anyString
    , argsParser
    , optionParser
    , createList
    )

import Parser exposing ((|.), Parser)
import Set
import Html exposing (Html)


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
    Parser.backtrackable <|
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

createList : ( String, String ) -> Html msg
createList ( a, b ) =
    Html.li []
        [ Html.span [] [ Html.text a ]
        , Html.span [] [ Html.text b ]
        ]
