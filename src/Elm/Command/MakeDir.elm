module Command.MakeDir exposing (..)
import Parser exposing (Parser, (|.), (|=))
import Command.ChangeDir exposing (argsParser)
import Utils
import Command.Help as Help exposing (HelpInfo(..))
import Html exposing (Html)
import Lazy.Tree as Tree
import Lazy.Tree.Zipper as Zipper exposing (Zipper(..))
import FileSystem as FS exposing (FileSystem(..))
import Command.State exposing (ProcState)


type MakeDir
    = MakeDir Args


type alias Args =
    { param : Maybe String
    , help : Bool
    }
    

type alias Flags =
    { fs : Zipper FileSystem
    }
    

type alias Proc =
    { param : Maybe String
    , help : Bool
    , fs : Zipper FileSystem
    }


parser : Parser MakeDir
parser =
    Parser.succeed MakeDir
        |. Parser.keyword "mkdir"
        |. Parser.spaces
        |= argsParser { param = Nothing, help = False }


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
        { name = "mkdir"
        , info = "Make directories"
        , detailInfo =
            [ HelpInfo
                { name = "<dir name>"
                , info = "The name of the FileSystem to create"
                , detailInfo = []
                }
            , HelpInfo
                { name = "[--help | -h]"
                , info = "How to use this command"
                , detailInfo = []
                }
            ]
        }


init : Args -> Flags -> (ProcState Proc, Cmd msg)
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
            (Command.State.Exit proc, Cmd.none)
        else if exist then
            (Command.State.Error proc "mkdir: File exists", Cmd.none)
        else
            (Command.State.Exit
                { proc
                    | fs =
                        proc.fs
                            |> Zipper.insert (Tree.singleton <| Directory_ { info = { name = dirName }, children = [] })
                }
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
