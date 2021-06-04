module Command.Egg exposing (..)

import Parser exposing (Parser, (|.), (|=))
import Utils
import Command.Help exposing (HelpInfo(..))
import Command.State exposing (ProcState)
import Html exposing (Html)
import CustomElement exposing (wcCodemirror)


type Egg = Egg Args


type alias Args = {}


type alias Flags = ()


type alias Proc = {}


type Msg = NoOp


parser : Parser Egg
parser =
    Parser.succeed Egg
        |. Parser.keyword "egg"
        |. Parser.spaces
        |= argsParser {}


argsParser : Args -> Parser Args
argsParser =
    Utils.argsParser <|
        \default ->
            Parser.oneOf []


info : HelpInfo
info =
    HelpInfo
        { name = "egg", info = "", detailInfo = [] }


init : Args -> Flags -> (ProcState Proc, Cmd Msg)
init args _ =
    ( Command.State.Exit {}, Cmd.none )


run : Msg -> Proc -> (ProcState Proc, Cmd Msg)
run msg proc =
    ( Command.State.Exit {}, Cmd.none )


view : Proc -> Html Msg
view proc =
    Html.div [] [ wcCodemirror [] [] ]


subscriptions : Proc -> Sub Msg
subscriptions _ =
    Sub.none