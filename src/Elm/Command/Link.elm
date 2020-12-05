module Command.Link exposing
    ( Args
    , Link(..)
    , parser
    , info
    , view
    , run
    )

import Parser exposing ((|.), (|=), Parser)
import Utils
import Command.Help as Help exposing (HelpInfo(..))
import Html exposing (Html)
import Html.Attributes as Attr
import Port
import Dict exposing (Dict(..))


type Link
    = Link Args


type alias Args =
    { help : Bool
    , yes : Bool
    , param : Maybe String
    }


parser : Parser Link
parser =
    Parser.succeed Link
        |. Parser.keyword "link"
        |. Parser.spaces
        |= argsParser { help = False, yes = False, param = Nothing }


argsParser : Args -> Parser Args
argsParser =
    Utils.argsParser <|
        \default ->
            Parser.oneOf
                [ Parser.succeed (\_ -> { default | help = True })
                    |= Utils.optionParser "h" "help"
                    |. Parser.spaces
                , Parser.succeed (\_ -> { default | yes = True })
                    |= Utils.optionParser "y" "yes"
                    |. Parser.spaces
                , Parser.succeed (\str -> { default | param = Just str })
                    |= Utils.anyString
                    |. Parser.spaces
                ]

info : HelpInfo
info =
    HelpInfo
        { name = "link"
        , info = "View the list of links to SNS, etc."
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


run : Link -> Dict String String -> Cmd msg
run (Link args) urlDict =
    if args.yes then
        args.param
            |> Maybe.andThen (\x -> Dict.get x urlDict)
            |> Maybe.map Port.openExternalLink
            |> Maybe.withDefault Cmd.none
    else
        Cmd.none        


view : Link -> Dict String String -> Html msg
view (Link args) links =
    if args.help then
        let
            (HelpInfo inner) = info
        in
        Help.view
            inner.info
            "[options]"
            inner.detailInfo
    else
        Html.div [ Attr.class "links" ]
            [ args.param
                |> Maybe.andThen (\x -> Dict.get x links)
                |> Maybe.map
                    (\url ->
                        Html.div [ Attr.class "list" ]
                            [ Html.text "Opens the specified link : "
                            , Html.a [ Attr.href url, Attr.target "_blink" ] [ Html.text url ]
                            ]
                    )
                |> Maybe.withDefault
                    (links
                        |> Dict.toList
                        |> List.map
                            (\( title, url ) ->
                                Html.li []
                                    [ Html.a [ Attr.href url, Attr.target "_blink" ] [ Html.text title ]
                                    ]
                            )
                        |> Html.ul [ Attr.class "list" ]
                    )
            ]
