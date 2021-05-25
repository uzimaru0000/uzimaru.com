module Command.Sleep exposing (..)

import Parser exposing (Parser, (|.), (|=))
import Utils
import Command.Help exposing (HelpInfo(..))
import Command.State exposing (ProcState)
import Html exposing (Html)
import Time

type Sleep = Sleep Args


type alias Args =
    { second : Maybe Int
    , help : Bool
    }


type alias Flags = ()


type alias Proc =
    { second : Int
    , help : Bool
    }


type Msg = Tick
    

parser : Parser Sleep
parser =
    Parser.succeed Sleep
        |. Parser.keyword "sleep"
        |. Parser.spaces
        |= argsParser { second = Nothing, help = False }
        

argsParser : Args -> Parser Args
argsParser =
    Utils.argsParser <|
        \default ->
            Parser.oneOf
                [ Parser.succeed (\_ -> { default | help = True })
                    |= Utils.optionParser "h" "help"
                    |. Parser.spaces
                , Parser.succeed (\n -> { default | second = Just n })
                    |= Parser.int
                    |. Parser.spaces
                ]

    
info : HelpInfo
info =
    HelpInfo
        { name = "sleep"
        , info = ""
        , detailInfo = []
        }


init : Args -> Flags -> (ProcState Proc, Cmd Msg)
init args _ =
    ( case args.second of
        Just s ->
            Command.State.Running
                { help = args.help
                , second = s
                }
        Nothing ->
            Command.State.Error
                { help = args.help
                , second = -1
                }
                "need seconds"
    , Cmd.none
    )
    

run : Msg -> Proc -> (ProcState Proc, Cmd Msg)
run msg proc =
    case msg of
        Tick ->
            (if proc.second - 1 > 0 then
                Command.State.Running
                    { proc | second = proc.second - 1 }
             else
                Command.State.Exit proc
            , Cmd.none
            )
            

view : Proc -> Html Msg
view proc =
    Html.div [] [ Html.text <| String.fromInt proc.second ]
    

subscriptions : Proc -> Sub Msg
subscriptions _ =
    Time.every 1000 (always Tick)
