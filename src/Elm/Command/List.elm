module Command.List exposing (..)

import Html exposing (Html)
import Html.Attributes as Attr
import Parser exposing ((|.), (|=), Parser)
import Utils
import Dict exposing (Dict)
import Directory exposing (Directory(..))
import Lazy.Tree.Zipper as Zipper exposing (Zipper)
import Command.Help exposing (HelpInfo(..))

type List
    = List Args

type alias Args =
    { long : Bool
    , all : Bool
    , param : Maybe String
    }


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
        , info = "List the contents of the directory"
        , detailInfo =
            [ HelpInfo
                { name = "[dir name]"
                , info = "The name of the target directory. If not, it will be the current directory"
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


view : List -> Zipper Directory -> Html msg
view (List args) dir =
    Html.div [ Attr.class "ls" ]
        [ dir
            |> Zipper.children
            |> List.map dirItem
            |> Html.ul []
        ]


dirItem : Directory -> Html cmd
dirItem dir =
    case dir of
        Directory { name } _ ->
            Html.li
                [ Attr.class "directory" ]
                [ Html.text <| name ++ "/" ]

        File { name } ->
            Html.li
                [ Attr.class "file" ]
                [ Html.text name ]
