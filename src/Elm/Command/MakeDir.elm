module Command.MakeDir exposing (..)
import Parser exposing (Parser, (|.), (|=))
import Command.ChangeDir exposing (argsParser)
import Utils
import Command.Help as Help exposing (HelpInfo(..))
import Html exposing (Html)
import Lazy.Tree as Tree
import Lazy.Tree.Zipper as Zipper exposing (Zipper(..))
import Directory as Dir exposing (Directory(..))


type MakeDir
    = MakeDir Args


type alias Args =
    { param : Maybe String
    , help : Bool
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
                , info = "The name of the directory to create"
                , detailInfo = []
                }
            , HelpInfo
                { name = "[--help | -h]"
                , info = "How to use this command"
                , detailInfo = []
                }
            ]
        }


run : MakeDir -> Zipper Directory -> Result String (Zipper Directory)
run (MakeDir args) dir =
    let
        dirName = Maybe.withDefault "" args.param

        exist = 
            dir
                |> Zipper.children
                |> List.any (Dir.getName >> (==) dirName)
    in
        if args.help then
            Ok dir
        else if exist then
            Err "mkdir: File exists"
        else
            dir
                |> Zipper.insert (Tree.singleton <| Directory { name = dirName } [])
                |> Ok


view : MakeDir -> Html msg
view (MakeDir args) =
    if args.help then
        let
            (HelpInfo inner) = info
        in
        Help.view
            inner.info
            "[options]"
            inner.detailInfo
    else
        Html.text ""
