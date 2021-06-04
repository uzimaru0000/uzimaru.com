module Utils exposing
    ( anyString
    , argsParser
    , optionParser
    , createList
    , bytesToString
    , stringToBytes
    )

import Parser exposing ((|.), Parser)
import Set
import Html exposing (Html)
import Html.Attributes as Attr
import Bytes exposing (Bytes)
import Bytes.Decode as BD
import Bytes.Encode as BE


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
    Html.li [ Attr.class "flex block w-full" ]
        [ Html.span [] [ Html.text a ]
        , Html.span [] [ Html.text b ]
        ]


-- sized string buffer
bytesToString : Bytes -> Maybe String
bytesToString =
    let
        decoder =
            BD.unsignedInt32 Bytes.BE
               |> BD.andThen BD.string
    in
    BD.decode decoder

stringToBytes : String -> Bytes
stringToBytes str =
    BE.encode <|
        BE.sequence
            [ BE.unsignedInt32 Bytes.BE (String.length str)
            , BE.string str
            ]
