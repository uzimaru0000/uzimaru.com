module Command.ChangeDir exposing (..)

import Parser exposing (Parser, (|.), (|=))
import Utils
import Html.Attributes exposing (default)
import Command.Help exposing (HelpInfo(..))
import Html exposing (Html)
import Lazy.Tree.Zipper as Zipper exposing (Zipper(..))
import Directory as Dir exposing (Directory(..))


type ChangeDir
    = ChangeDir Args


type alias Args =
    { param : Maybe String
    }


type Error
    = NotExist
    | TargetIsFile


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
        , info = "Change Directory"
        , detailInfo =
            [ HelpInfo
                { name = "[dir name]"
                , info = "The name of the destination directory"
                , detailInfo = []
                }
            ]
        }


run : ChangeDir -> Zipper Directory -> Result String (Zipper Directory)
run (ChangeDir args) dir =
    case args.param of
        Just path ->
            changeDirHelper (String.split "/" path) dir
                |> Result.mapError
                    (\x ->
                        case x of
                            NotExist ->
                                "cd: The directory '" ++ path ++ "' does not exist"
                            TargetIsFile ->
                                "cd: '" ++ path ++ "' is not a directory"
                    )
        Nothing ->
            Ok <| Zipper.root dir


changeDirHelper : List String -> Zipper Directory -> Result Error (Zipper Directory)
changeDirHelper path dir =
    case path of
        ".." :: tail ->
            dir
                |> Zipper.up
                |> Result.fromMaybe NotExist
                |> Result.andThen (changeDirHelper tail)

        "." :: tail ->
            changeDirHelper tail dir

        head :: tail ->
            dir
                |> Zipper.open
                    (\x ->
                        case x of
                            Directory { name } _ ->
                                name == head

                            File _ ->
                                False
                    )
                |> Result.fromMaybe
                    (case Zipper.open (Dir.getName >> (==) head) dir |> Maybe.map Zipper.current of
                        Just (File _) ->
                            TargetIsFile

                        Nothing ->
                            NotExist

                        _ ->
                            NotExist
                    )
                |> Result.andThen (changeDirHelper tail)

        [] ->
            Ok dir


view : Html msg
view =
    Html.text ""
