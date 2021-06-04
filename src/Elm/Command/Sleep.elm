module Command.Sleep exposing (..)

import Parser exposing (Parser, (|.), (|=))
import Utils
import Command.Help exposing (HelpInfo(..))
import Command.State exposing (ProcState)
import Html exposing (Html)
import Html.Attributes as Attr
import Time
import Html exposing (progress)

type Sleep = Sleep Args


type alias Args =
    { second : Maybe Int
    , help : Bool
    }


type alias Flags = ()


type alias Proc =
    { second : Int
    , max : Int
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
                , max = s
                }
        Nothing ->
            Command.State.Error
                { help = args.help
                , second = -1
                , max = -1
                }
                "need seconds"
    , Cmd.none
    )
    

run : Msg -> Proc -> (ProcState Proc, Cmd Msg)
run msg proc =
    case msg of
        Tick ->
            (if proc.second - 1 >= 0 then
                Command.State.Running
                    { proc | second = proc.second - 1 }
             else
                Command.State.Exit proc
            , Cmd.none
            )
            

view : Proc -> Html Msg
view proc =
    Html.div
        [ Attr.class "whitespace-pre" ]
        [ Html.text <| bar 50 proc.second proc.max ]


bar : Int -> Int -> Int -> String
bar width n max =
    let
        unit = 1 / toFloat max
        progress = toFloat width * (toFloat (max - n) * unit)
        blank = String.repeat (width - floor progress) " "
        gage = String.repeat (floor progress) "-"
    in
    "<" ++ gage ++ blank ++ ">"
    

subscriptions : Proc -> Sub Msg
subscriptions _ =
    Time.every 1000 (always Tick)
