module Command.Remove exposing (..)

import Parser exposing (Parser, (|.), (|=))
import Utils
import Command.Help as Help exposing (HelpInfo(..))
import Html exposing (Html)
import Lazy.Tree.Zipper as Zipper exposing (Zipper(..))
import FileSystem as FS exposing (FileSystem(..))
import Command.State exposing (ProcState)

type Remove
    = Remove Args


type alias Args =
    { help : Bool
    , recursive : Bool
    , param : Maybe String
    }
    

type alias Flags =
    { fs : Zipper FileSystem
    }


type alias Proc =
    { help : Bool
    , recursive : Bool
    , param : Maybe String
    , fs : Zipper FileSystem
    }
    

parser : Parser Remove
parser =
    Parser.succeed Remove
        |. Parser.keyword "rm"
        |. Parser.spaces
        |= argsParser { help = False, recursive = False, param = Nothing }


argsParser : Args -> Parser Args
argsParser =
    Utils.argsParser <|
        \default ->
            Parser.oneOf
                [ Parser.succeed (\_ -> { default | help = True })
                    |= Utils.optionParser "h" "help"
                    |. Parser.spaces
                , Parser.succeed (\_ -> { default | recursive = True })
                    |= Utils.optionParser "r" "recursive"
                    |. Parser.spaces
                , Parser.succeed (\str -> { default | param = Just str })
                    |= Utils.anyString
                    |. Parser.spaces
                ]


info : HelpInfo
info =
    HelpInfo
        { name = "rm"
        , info = "remove FileSystem entries"
        , detailInfo = []
        }
        
    
init : Args -> Flags -> (ProcState Proc, Cmd msg)
init args flags =
    let
        path = Maybe.withDefault "" args.param
        newFS =
            flags.fs
                |> Zipper.openPath (\p d -> p == FS.getName d) (String.split "/" path)
                |> Result.mapError (always "rm: No such file or directory")
                |> Result.andThen
                    (\d ->
                        case (args.recursive, Zipper.current d) of
                            (False, Directory_ _) ->
                                Err <| "rm: " ++ path ++ ": is a directory"
                            _ ->
                                Ok d
                    )
                |> Result.map (Zipper.attempt Zipper.delete)
                    
        proc =
            { param = args.param
            , help = args.help
            , recursive = args.recursive
            , fs = flags.fs
            }
    in
    case newFS of
        Ok fs ->
            ( Command.State.Exit { proc | fs = fs }
            , Cmd.none)
        
        Err err ->
            ( Command.State.Error proc err
            , Cmd.none
            )



run : Never -> Proc -> (ProcState Proc, Cmd msg)
run _ proc =
    (Command.State.Exit proc, Cmd.none)


view : Proc -> Html msg
view { help } =
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
        Html.text ""

