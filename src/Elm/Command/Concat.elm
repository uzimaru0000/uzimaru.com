module Command.Concat exposing (..)
import Parser exposing (Parser, (|.), (|=))
import Utils
import Parser exposing (succeed)
import Command.Help as Help exposing (HelpInfo(..))
import Lazy.Tree as Tree
import Lazy.Tree.Zipper as Zipper exposing (Zipper(..))
import FileSystem as FS exposing (FileSystem(..), Error(..))
import Html exposing (..)
import Debug

type Concat
    = Concat Args

type alias Args =
    { help : Bool
    , param : Maybe String
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


view : Concat -> Zipper FileSystem -> Html msg
view (Concat args) fs =
    if args.help then
        let
            (HelpInfo inner) = info
        in
        Help.view
            inner.name
            "[options]"
            inner.detailInfo
    else
        case args.param |> Maybe.map (String.split "/") of
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
