module Command.WhoAmI exposing (..)

import Parser exposing (Parser, (|=), (|.))
import Utils
import Html exposing (Html)
import Html.Attributes as Attr
import Command.Help as Help exposing (HelpInfo(..))
import Icon exposing (icon)
import Command.State exposing (ProcState)


type WhoAmI
    = WhoAmI Args

type alias Args =
    { help : Bool
    }
    

type alias Flags =
    { infos: List (String, String)
    }


type alias Proc =
    { help : Bool
    , infos : List (String, String)
    }
    

type Msg = NoOp


parser : Parser WhoAmI
parser =
    Parser.succeed WhoAmI
        |. Parser.keyword "whoami"
        |. Parser.spaces
        |= argsParser { help = False }


argsParser : Args -> Parser Args
argsParser =
    Utils.argsParser <|
        \default ->
            Parser.oneOf
                [ Parser.succeed (\_ -> { default | help = True })
                    |= Utils.optionParser "h" "help"
                    |. Parser.spaces
                ]

info : HelpInfo
info =
    HelpInfo
        { name = "whoami"
        , info = "Show information about me."
        , detailInfo =
            [ HelpInfo
                { name = "[--help | -h]"
                , info = "How to use this command"
                , detailInfo = []
                }
            ]
        }
        

init : Args -> Flags -> (ProcState Proc, Cmd Msg)
init args flags =
    (Command.State.Exit 
        { help = args.help
        , infos = flags.infos
        }
    , Cmd.none
    )
    

run : Msg -> Proc -> (ProcState Proc, Cmd Msg)
run _ proc =
    (Command.State.Exit proc, Cmd.none)


view : Proc -> Html msg
view { help, infos } =
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
        Html.div [ Attr.class "flex p-4" ]
            [ Html.figure [ Attr.class "w-1/5 mr-4" ] [ icon ]
            , infos
                |> List.map
                    (\(a, b) ->
                        Html.div
                            [ Attr.class "flex w-full" ]
                            [ Html.span [ Attr.class "w-1/5" ] [ Html.text a ]
                            , Html.span [ Attr.class "w-4/5" ] [ Html.text b ]
                            ]
                    )
                |> Html.div [ Attr.class "flex flex-col justify-evenly w-4/5" ]
            ]

