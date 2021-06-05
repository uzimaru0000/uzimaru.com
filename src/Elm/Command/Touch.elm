module Command.Touch exposing (..)

import Parser exposing (Parser, (|.), (|=))
import Utils
import Command.Help as Help exposing (HelpInfo(..))
import Html exposing (Html)
import Lazy.Tree as Tree
import Lazy.Tree.Zipper as Zipper exposing (Zipper(..))
import FileSystem as FS exposing (FileSystem(..))
import Bytes.Encode as BE
import Command.State exposing (ProcState)


type Touch
    = Touch Args


type alias Args =
    { help : Bool
    , param : Maybe String
    }
    

type alias Flags =
    { fs : Zipper FileSystem
    }
    

type alias Proc =
    { help : Bool
    , param : Maybe String
    , fs : Zipper FileSystem
    }
    

type Msg = Never


parser : Parser Touch
parser =
    Parser.succeed Touch
        |. Parser.keyword "touch"
        |. Parser.spaces
        |= argsParser { help = False, param = Nothing }


argsParser : Args -> Parser Args
argsParser =
    Utils.argsParser <|
        \default ->
            Parser.oneOf
                [ Parser.succeed (\_ -> { default | help = True })
                    |= Utils.optionParser "h" "help"
                    |. Parser.spaces
                , Parser.succeed (\str -> { default | param = Just str })
                    |= Utils.anyString
                    |. Parser.spaces
                ]


info : HelpInfo
info =
    HelpInfo
        { name = "touch"
        , info = "change file access and modification times"
        , detailInfo = []
        }


init : Args -> Flags -> (ProcState Proc, Cmd Msg)
init args flags =
    let
        dirName = Maybe.withDefault "" args.param

        exist = 
            flags.fs
                |> Zipper.children
                |> List.any (FS.getName >> (==) dirName)
                
        proc =
            { help = args.help
            , param = args.param
            , fs = flags.fs
            }
    in
        if args.help then
            ( Command.State.Exit proc
            , Cmd.none
            )
        else if exist then
            ( Command.State.Error proc "touch: File exists"
            , Cmd.none
            )
        else
            ( Command.State.Exit
                { proc
                    | fs =
                        proc.fs
                            |> Zipper.insert
                                ({ info = { name = dirName }
                                 , data = Utils.stringToBytes ""
                                 }
                                    |> File_
                                    |> Tree.singleton
                                )
                }
            , Cmd.none
            )


run : Msg -> Proc -> (ProcState Proc, Cmd Msg)
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
