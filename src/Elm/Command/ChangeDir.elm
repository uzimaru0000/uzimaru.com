module Command.ChangeDir exposing (..)

import Parser exposing (Parser, (|.), (|=))
import Utils
import Html.Attributes exposing (default)
import Command.Help exposing (HelpInfo(..))
import Html exposing (Html)
import Lazy.Tree.Zipper as Zipper exposing (Zipper(..))
import FileSystem as FS exposing (FileSystem(..), Error(..))
import Command.State exposing (ProcState)


type ChangeDir
    = ChangeDir Args


type alias Args =
    { param : Maybe String
    }
    

type alias Flags =
    { fs : Zipper FileSystem
    }
    

type alias Proc =
    { param : Maybe String
    , fs : Zipper FileSystem
    }
    

parser : Parser ChangeDir
parser =
    Parser.succeed ChangeDir
        |. Parser.keyword "cd"
        |. Parser.spaces
        |= argsParser { param = Nothing }


argsParser : Args -> Parser Args
argsParser =
    Utils.argsParser <|
        \default ->
            Parser.oneOf
                [ Parser.succeed (\str -> { default | param = Just str })
                    |= Utils.anyString
                    |. Parser.spaces
                ]


info : HelpInfo
info =
    HelpInfo
        { name = "cd"
        , info = "Change FileSystem"
        , detailInfo =
            [ HelpInfo
                { name = "[dir name]"
                , info = "The name of the destination FileSystem"
                , detailInfo = []
                }
            ]
        }
        

init : Args -> Flags -> (ProcState Proc, Cmd msg)
init args flags =
    let
        cd =
            case args.param of
                Just path ->
                    FS.cwd (String.split "/" path) flags.fs
                        |> Result.mapError
                            (\x ->
                                case x of
                                    TargetIsFile ->
                                        "cd: '" ++ path ++ "' is not a FileSystem"
                                    _ ->
                                        "cd: The FileSystem '" ++ path ++ "' does not exist"
                            )

                Nothing ->
                    Ok <| Zipper.root flags.fs
    in
        case cd of
            Ok fs ->
                ( Command.State.Exit
                    { fs = fs
                    , param = args.param
                    }
                , Cmd.none
                )
            
            Err err ->
                ( Command.State.Error
                    { fs = flags.fs
                    , param = args.param
                    }
                    err
                , Cmd.none
                )


run : Never -> Proc -> (ProcState Proc, Cmd msg)
run _ proc =
    (Command.State.Exit proc, Cmd.none)


view : Proc -> Html msg
view _ =
    Html.text ""
