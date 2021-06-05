module Command.Egg exposing (..)

import Parser exposing (Parser, (|.), (|=))
import Utils
import Command.Help exposing (HelpInfo(..))
import Command.State exposing (ProcState)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Ev
import Lazy.Tree.Zipper as Zipper exposing (Zipper)
import FileSystem as FS exposing (FileSystem(..), Error(..))
import Json.Decode as JD
import Task
import Browser.Dom


type Egg = Egg Args


type alias Args =
    { file : String
    }


type alias Flags =
    { fs : Zipper FileSystem
    }


type alias Proc =
    { content : String
    , fs : Zipper FileSystem
    , path : List String
    }


type Msg
    = Save
    | Input String
    | Focus


parser : Parser Egg
parser =
    Parser.succeed Egg
        |. Parser.keyword "egg"
        |. Parser.spaces
        |= argsParser { file = "" }


argsParser : Args -> Parser Args
argsParser =
    Utils.argsParser <|
        \default ->
            Parser.oneOf
                [ Parser.succeed (\str -> { default | file = str })
                    |= Utils.anyString
                    |. Parser.spaces
                ]


info : HelpInfo
info =
    HelpInfo
        { name = "egg", info = "", detailInfo = [] }


init : Args -> Flags -> (ProcState Proc, Cmd Msg)
init args flags =
    if String.isEmpty args.file then
        ( Command.State.Error
            { content = ""
            , fs = flags.fs
            , path = []
            }
            "Select file"
        , Cmd.none
        )
    else
        let
            path =  String.split "/" args.file
            content =
                FS.readFile path flags.fs
                    |> Result.map .data
                    |> Result.andThen
                        (\buf ->
                            Utils.bytesToString buf
                                |> Result.fromMaybe InvalidData
                        )
        in
        ( case content of
            Ok content_ ->
                Command.State.Running
                { content = content_
                , fs = flags.fs
                , path = path
                }
            Err err ->
                Command.State.Error
                    { content = ""
                    , fs = flags.fs
                    , path = path
                    }
                    (FS.errorToString err)
        ,  Task.attempt (\_ -> Focus) <| Browser.Dom.focus "editor"
        )


run : Msg -> Proc -> (ProcState Proc, Cmd Msg)
run msg proc =
    case msg of
        Input str ->
            ( Command.State.Running
                { proc |
                    content = str
                }
            , Cmd.none
            )

        Save ->
            let
                newFS =
                    FS.writeFile
                        proc.path
                        (Utils.stringToBytes proc.content)
                        proc.fs
            in
            case newFS of
                Ok fs ->
                    ( Command.State.Exit { proc | fs = fs }
                    , Cmd.none
                    )
                Err err ->
                    ( Command.State.Error
                        proc
                        (FS.errorToString err)
                    , Cmd.none
                    )

        Focus ->
            ( Command.State.Running proc, Cmd.none )


view : Proc -> Html Msg
view proc =
    Html.textarea 
        [ Attr.id "editor"
        , Attr.class "text-lightGreen bg-transparent border-none p-4 resize-none w-full h-full"
        , Attr.value proc.content
        , onKeyDownWithCtrl
            (\ctrl code ->
                case (ctrl, code) of
                    (True, 83) -> JD.succeed Save
                    _ -> JD.fail "no matched"
            )
        , Ev.onInput Input
        ]
        []


onKeyDownWithCtrl : (Bool -> Int -> JD.Decoder msg) -> Html.Attribute msg
onKeyDownWithCtrl decoder =
    JD.map2 decoder
        (JD.field "ctrlKey" JD.bool)
        (JD.field "keyCode" JD.int)
        |> JD.andThen identity
        |> JD.map (\x -> (x, True))
        |> Ev.preventDefaultOn "keydown"


subscriptions : Proc -> Sub Msg
subscriptions _ =
    Sub.none