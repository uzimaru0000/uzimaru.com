module Command.Work exposing (..)

import Parser exposing ((|.), (|=), Parser)
import Utils
import Command.Help as Help exposing (HelpInfo(..))
import Html exposing (Html)
import Html.Attributes as Attr
import Dict exposing (Dict(..))
import Port


type Work
    = Work Args


type alias Args =
    { help : Bool
    , yes : Bool
    , param : Maybe String
    }


parser : Parser Work
parser =
    Parser.succeed Work
        |. Parser.keyword "work"
        |. Parser.spaces
        |= argsParser { help = False, yes = False, param = Nothing } 


argsParser : Args -> Parser Args
argsParser =
    Utils.argsParser <|
        \default ->
            Parser.oneOf
                [ Parser.succeed (\_ -> { default | yes = True })
                    |= Utils.optionParser "y" "yes"
                    |. Parser.spaces
                , Parser.succeed (\_ -> { default | help = True })
                    |= Utils.optionParser "h" "help"
                    |. Parser.spaces
                , Parser.succeed (\str -> { default | param = Just str })
                    |= Utils.anyString
                    |. Parser.spaces
                ]


info : HelpInfo
info =
    HelpInfo
        { name = "work"
        , info = "View a list of things I've made."
        , detailInfo =
            [ HelpInfo
                { name = "[link name]"
                , info = "The name of the link you want to open"
                , detailInfo = []
                }
            , HelpInfo
                { name = "[--yes | -y]"
                , info = "If this option is enabled, the specified link will be accessed automatically"
                , detailInfo = []
                }
            , HelpInfo
                { name = "[--help | -h]"
                , info = "How to use this command"
                , detailInfo = []
                }
            ]
        }

run : Work -> Dict String (String, String) -> Cmd msg
run (Work args) urlDict =
    if args.yes then
        args.param
            |> Maybe.andThen (\x -> Dict.get x urlDict)
            |> Maybe.map (\(_, url) -> Port.openExternalLink url)
            |> Maybe.withDefault Cmd.none
    else
        Cmd.none
        

view : Work -> Dict String (String, String) -> Html msg
view (Work args) links =
    if args.help then
        let
            (HelpInfo inner) = info
        in
        Help.view
            inner.info
            "[options]"
            inner.detailInfo
    else
        args.param
            |> Maybe.andThen (\x -> Dict.get x links)
            |> Maybe.map
                (\(_, url) ->
                    Html.div [ Attr.class "list" ]
                        [ Html.text "Opens the specified link : "
                        , Html.a [ Attr.href url, Attr.target "_blink" ] [ Html.text url ]
                        ]
                )
            |> Maybe.withDefault
                (Html.div [ Attr.class "work" ]
                    [ links
                        |> Dict.toList
                        |> List.map
                            (\( title, (subTitle, url) ) ->
                                Html.li []
                                    [ Html.a [ Attr.href url, Attr.target "_blink" ] [ Html.text title ]
                                    , Html.span [] [ Html.text subTitle ]
                                    ]
                            )
                        |> Html.ul [ Attr.class "list" ]
                    ]
                )
