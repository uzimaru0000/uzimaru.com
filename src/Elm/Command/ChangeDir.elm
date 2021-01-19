module Command.ChangeDir exposing (..)

import Parser exposing (Parser, (|.), (|=))
import Utils
import Html.Attributes exposing (default)
import Command.Help exposing (HelpInfo(..))
import Html exposing (Html)
import Lazy.Tree.Zipper as Zipper exposing (Zipper(..))
import FileSystem as FS exposing (FileSystem(..), Error(..))


type ChangeDir
    = ChangeDir Args


type alias Args =
    { param : Maybe String
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


run : ChangeDir -> Zipper FileSystem -> Result String (Zipper FileSystem)
run (ChangeDir args) dir =
    case args.param of
        Just path ->
            FS.cwd (String.split "/" path) dir
                |> Result.mapError
                    (\x ->
                        case x of
                            TargetIsFile ->
                                "cd: '" ++ path ++ "' is not a FileSystem"
                            _ ->
                                "cd: The FileSystem '" ++ path ++ "' does not exist"
                    )
        Nothing ->
            Ok <| Zipper.root dir


view : Html msg
view =
    Html.text ""
