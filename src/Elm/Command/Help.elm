module Command.Help exposing
    ( Help(..)
    , HelpInfo(..)
    , view
    , viewHelper
    , info
    , parser
    )

import Html exposing (Html)
import Html.Attributes as Attr
import Parser exposing ((|.), (|=), Parser)
import Utils
import Dict exposing (Dict)


type Help
    = Help


type HelpInfo =
    HelpInfo
        { name : String
        , info : String
        , detailInfo : List HelpInfo
        }


parser : Parser Help
parser =
    Parser.succeed Help
        |. Parser.keyword "help"
        |. Parser.spaces


info : HelpInfo
info =
    HelpInfo
        { name = "help"
        , info = "Show how to use the command."
        , detailInfo = []
        }


view : String -> String -> List HelpInfo -> Html msg
view message label infos =
    Html.div [ Attr.class "help" ]
        [ Html.div [ Attr.class "message" ]
            [ Html.text message ]
        , Html.div []
            [ Html.text label ]
        , Html.div [ Attr.class "detail" ]
            ( infos
                |> List.map viewHelper
            )
        ]

viewHelper : HelpInfo -> Html msg
viewHelper (HelpInfo i) =
    Html.div
        [ Attr.class "description" ]
        [ Html.div [] [ Html.text i.name ]
        , Html.div [ Attr.class "info" ] [ Html.text i.info ]
        ]
