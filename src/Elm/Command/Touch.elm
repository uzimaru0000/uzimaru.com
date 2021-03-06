module Command.Touch exposing (..)

import Parser exposing (Parser, (|.), (|=))
import Utils
import Command.Help as Help exposing (HelpInfo(..))
import Html exposing (Html)
import Lazy.Tree as Tree
import Lazy.Tree.Zipper as Zipper exposing (Zipper(..))
import FileSystem as FS exposing (FileSystem(..))
import Bytes.Encode as BE


type Touch
    = Touch Args


type alias Args =
    { help : Bool
    , param : Maybe String
    }


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


run : Touch -> Zipper FileSystem -> Result String (Zipper FileSystem)
run (Touch args) dir =
    let
        dirName = Maybe.withDefault "" args.param

        exist = 
            dir
                |> Zipper.children
                |> List.any (FS.getName >> (==) dirName)
    in
        if args.help then
            Ok dir
        else if exist then
            Err "mkdir: File exists"
        else
            dir
                |> Zipper.insert
                    ({ info = { name = dirName }
                     , data = BE.encode <| BE.string ""
                     }
                        |> File_
                        |> Tree.singleton
                    )
                |> Ok


view : Touch -> Html msg
view (Touch args) =
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
