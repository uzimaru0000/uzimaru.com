module Command.Work exposing (..)

import Parser exposing ((|.), (|=), Parser)
import Utils
import Command.Help as Help exposing (HelpInfo(..))
import Html exposing (Html)
import Html.Attributes as Attr
import Dict exposing (Dict(..))
import Port
import Command.State exposing (ProcState)


type Work
    = Work Args


type alias Args =
    { help : Bool
    , yes : Bool
    , param : Maybe String
    }
    

type alias Flags =
    { works : Dict String (String, String)  
    }


type alias Proc =
    { help : Bool
    , yes : Bool
    , param : Maybe String
    , works : Dict String (String, String) 
    }
    

type Msg = NoOp


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
        

init : Args -> Flags -> (ProcState Proc, Cmd Msg)
init args flags =
    ( Command.State.Exit
        { help = args.help
        , yes = args.yes
        , param = args.param
        , works = flags.works
        }
    , if args.yes then
        args.param
            |> Maybe.andThen (\x -> Dict.get x flags.works)
            |> Maybe.map (\(_, url) -> Port.openExternalLink url)
            |> Maybe.withDefault Cmd.none
      else
        Cmd.none
    )


run : Msg -> Proc -> (ProcState Proc, Cmd Msg)
run _ proc =
    ( Command.State.Exit proc
    , Cmd.none
    )
        

view : Proc -> Html msg
view { help, param, works } =
    if help then
        let
            (HelpInfo inner) = info
        in
        Help.view
            { message = inner.info
            , label = "[options]"
            , infos = inner.detailInfo
            }
    else
        param
            |> Maybe.andThen (\x -> Dict.get x works)
            |> Maybe.map
                (\(_, url) ->
                    Html.div [ Attr.class "p-4" ]
                        [ Html.text "Opens the specified link : "
                        , Html.a
                            [ Attr.href url
                            , Attr.target "_blink"
                            , Attr.class "text-yellow hover:underline"
                            ]
                            [ Html.text url ]
                        ]
                )
            |> Maybe.withDefault
                (works
                    |> Dict.toList
                    |> List.map
                        (\( title, (subTitle, url) ) ->
                            Html.li [ Attr.class "flex" ]
                                [ Html.a
                                    [ Attr.href url
                                    , Attr.target "_blink"
                                    , Attr.class "text-yellow hover:underline w-1/5"
                                    ]
                                    [ Html.text title ]
                                , Html.span
                                    [ Attr.class "w-4/5" ]
                                    [ Html.text subTitle ]
                                ]
                        )
                    |> Html.ul [ Attr.class "p-4" ]
                )
