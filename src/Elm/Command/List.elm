module Command.List exposing (..)

import Html exposing (Html)
import Html.Attributes as Attr
import Parser exposing ((|.), (|=), Parser)
import Utils
import Dict exposing (Dict)
import FileSystem exposing (FileSystem(..))
import Lazy.Tree.Zipper as Zipper exposing (Zipper)
import Command.Help exposing (HelpInfo(..))
import Command.State exposing (ProcState)

type List
    = List Args

type alias Args =
    { long : Bool
    , all : Bool
    , param : Maybe String
    }
    

type alias Flags =
    { fs : Zipper FileSystem
    }
    

type alias Proc =
    { long : Bool
    , all : Bool
    , param : Maybe String
    , fs : Zipper FileSystem
    }
    

type Msg = NoOp


parser : Parser List
parser =
    Parser.succeed List
        |. Parser.keyword "ls"
        |. Parser.spaces
        |= argsParser { long = False, all = False, param = Nothing }


argsParser : Args -> Parser Args
argsParser =
    Utils.argsParser <|
        \default ->
            Parser.oneOf
                [ Parser.succeed (\_ -> { default | long = True })
                    |= Utils.optionParser "l" "long"
                    |. Parser.spaces
                , Parser.succeed (\_ -> { default | all = True })
                    |= Utils.optionParser "a" "all"
                    |. Parser.spaces
                , Parser.succeed (\str -> { default | param = Just str })
                    |= Utils.anyString
                    |. Parser.spaces
                ]


info : HelpInfo
info =
    HelpInfo
        { name = "ls"
        , info = "List the contents of the FileSystem"
        , detailInfo =
            [ HelpInfo
                { name = "[dir name]"
                , info = "The name of the target FileSystem. If not, it will be the current FileSystem"
                , detailInfo = []
                }
            , HelpInfo
                { name = "[--long | -l]"
                , info = "View detailed information"
                , detailInfo = []
                }
            , HelpInfo
                { name = "[--all | -a]"
                , info = "View all files and directories"
                , detailInfo = []
                }
            , HelpInfo
                { name = "[--help | -h]"
                , info = ""
                , detailInfo = []
                }
            ]
        }
        

init : Args -> Flags -> (ProcState Proc, Cmd Msg)
init args flags =
    ( Command.State.Exit
        { long = args.long
        , all = args.all
        , param = args.param
        , fs = flags.fs
        }
    , Cmd.none
    )
    

run : Msg -> Proc -> (ProcState Proc, Cmd Msg)
run _ proc =
    ( Command.State.Exit proc, Cmd.none )


view : Proc -> Html msg
view { fs } =
    Html.div [ Attr.class "ls" ]
        [ fs
            |> Zipper.children
            |> List.map dirItem
            |> Html.ul []
        ]


dirItem : FileSystem -> Html cmd
dirItem fs =
    case fs of
        Directory_ dir ->
            Html.li
                [ Attr.class "directory" ]
                [ Html.text <| dir.info.name ++ "/" ]

        File_ file ->
            Html.li
                [ Attr.class "file" ]
                [ Html.text file.info.name ]
