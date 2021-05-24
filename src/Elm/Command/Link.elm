module Command.Link exposing
    ( Args
    , Link(..)
    , Msg(..)
    , Proc
    , parser
    , info
    , init
    , view
    , run
    )

import Parser exposing ((|.), (|=), Parser)
import Utils
import Command.Help as Help exposing (HelpInfo(..))
import Html exposing (Html)
import Html.Attributes as Attr
import Dict exposing (Dict(..))
import Command.State as State exposing (ProcState(..))
import Port


type Link = Link Args

type alias Proc =
    { args: Args
    , urls: Dict String String
    }


type alias Args =
    { help : Bool
    , yes : Bool
    , param : Maybe String
    }
    

type alias Flags = Dict String String


type Msg = NoOp


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


init : Args -> Flags -> Proc
init args urls =
    { args = args
    , urls = urls
    }
    

run : Msg -> Proc -> (ProcState Proc, Cmd Msg)
run _ proc =
    ( State.Exit proc
    , if proc.args.yes then
        proc.args.param
            |> Maybe.andThen (\x -> Dict.get x proc.urls)
            |> Maybe.map Port.openExternalLink
            |> Maybe.withDefault Cmd.none
      else
        Cmd.none
    )


view : Proc -> Html msg
view { args, urls } =
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
                |> Maybe.andThen (\x -> Dict.get x urls)
                |> Maybe.map
                    (\url ->
                        Html.div [ Attr.class "list" ]
                            [ Html.text "Opens the specified link : "
                            , Html.a [ Attr.href url, Attr.target "_blink" ] [ Html.text url ]
                            ]
                    )
                |> Maybe.withDefault
                    (urls
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
