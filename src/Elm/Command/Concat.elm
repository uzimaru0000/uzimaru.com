module Command.Concat exposing (..)
import Parser exposing (Parser, (|.), (|=))
import Utils
import Command.Help as Help exposing (HelpInfo(..))
import Lazy.Tree.Zipper exposing (Zipper(..))
import FileSystem as FS exposing (FileSystem(..), Error(..))
import Html exposing (..)
import Command.State exposing (ProcState)

type Concat
    = Concat Args

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


parser : Parser Concat
parser =
    Parser.succeed Concat
        |. Parser.keyword "cat"
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
        

init : Args -> Flags -> (ProcState Proc, Cmd msg)
init args flags =
    ( Command.State.Exit
        { help = args.help
        , param = args.param
        , fs = flags.fs
        }
    , Cmd.none
    )
    

run : Never -> Proc -> (ProcState Proc, Cmd msg)
run _ proc =
    ( Command.State.Exit proc
    , Cmd.none
    )


view : Proc -> Html msg
view { help, param, fs } =
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
        case param |> Maybe.map (String.split "/") of
            Just path ->
                FS.readFile path fs
                    |> Result.map .data
                    |> Result.andThen
                        (\buf ->
                            Utils.bytesToString buf
                                |> Result.fromMaybe InvalidData
                        )
                    |> viewHelper
            Nothing ->
                Html.text ""


viewHelper : Result FS.Error String -> Html msg
viewHelper result =
    case result of
        Ok data ->
            Html.div
                []
                [ Html.pre [] [ Html.text data ]
                ]
        Err err ->
            errorView err


errorView : FS.Error -> Html msg
errorView err =
    case err of
        NotExist ->
            Html.div [] [ Html.text "cat: No such file or directory" ]

        
        TargetIsFileSystem ->
            Html.div [] [ Html.text "cat: Is a directory" ]
        
        _ ->
            Html.div [] [ Html.text "cat: Error" ]
