module Command.Help exposing
    ( Help(..)
    , HelpInfo(..)
    , Flags
    , Proc
    , Msg(..)
    , init
    , run
    , view
    , viewHelper
    , info
    , parser
    )

import Html exposing (Html)
import Html.Attributes as Attr
import Parser exposing ((|.), (|=), Parser)
import Command.State as State exposing (ProcState)


type Help
    = Help
    

type alias Proc =
    { message : String
    , label : String
    , infos : List HelpInfo
    }


type alias Args = ()


type alias Flags =
    { message : String
    , label : String
    , infos : List HelpInfo
    }


type Msg = NoOp


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
        

init : Args -> Flags -> (ProcState Proc, Cmd Msg)
init _ flags =
    (State.Exit
        { message = flags.message
        , label = flags.label
        , infos = flags.infos
        }
    , Cmd.none
    )


run : Msg -> Proc -> (ProcState Proc, Cmd Msg)
run _ proc =
    ( State.Exit proc, Cmd.none )


view : Proc -> Html msg
view { message, label, infos } =
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
