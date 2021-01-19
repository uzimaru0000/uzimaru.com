module Command.Remove exposing (..)

import Parser exposing (Parser, (|.), (|=))
import Utils
import Command.Help as Help exposing (HelpInfo(..))
import Html exposing (Html)
import Lazy.Tree as Tree
import Lazy.Tree.Zipper as Zipper exposing (Zipper(..))
import FileSystem as FS exposing (FileSystem(..))

type Remove
    = Remove Args


type alias Args =
    { help : Bool
    , recursive : Bool
    , param : Maybe String
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


run : Remove -> Zipper FileSystem -> Result String (Zipper FileSystem)
run (Remove args) dir =
    let
        path = Maybe.withDefault "" args.param
        newDir =
            dir
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
    in
    newDir
        |> Result.map (Zipper.attempt Zipper.delete)


view : Remove -> Html msg
view (Remove args) =
    if args.help then
        let
            (HelpInfo inner) = info
        in
        Help.view
            inner.name
            "[options]"
            inner.detailInfo
    else
        Html.text ""

