module Command.WhoAmI exposing (..)

import Parser exposing (Parser, (|=), (|.))
import Utils
import Html exposing (Html, text)
import Html.Attributes as Attr
import Command.Help as Help exposing (HelpInfo(..))
import Icon exposing (icon)


type WhoAmI
    = WhoAmI Args

type alias Args =
    { help: Bool
    }


parser : Parser WhoAmI
parser =
    Parser.succeed WhoAmI
        |. Parser.keyword "whoami"
        |. Parser.spaces
        |= argsParser { help = False }


argsParser : Args -> Parser Args
argsParser =
    Utils.argsParser <|
        \default ->
            Parser.oneOf
                [ Parser.succeed (\_ -> { default | help = True })
                    |= Utils.optionParser "h" "help"
                    |. Parser.spaces
                ]

info : HelpInfo
info =
    HelpInfo
        { name = "whoami"
        , info = "Show information about me."
        , detailInfo =
            [ HelpInfo
                { name = "<--help | -h>"
                , info = "How to use this command"
                , detailInfo = []
                }
            ]
        }


view : WhoAmI -> List (String, String) -> Html msg
view (WhoAmI args) i =
    if args.help then
        let
            (HelpInfo inner) = info
        in
        Help.view
            inner.info
            "[options]"
            inner.detailInfo
    else
        Html.div [ Attr.class "whoami" ]
            [ Html.figure [] [ icon ]
            , i
                |> List.map Utils.createList
                |> Html.ul [ Attr.class "list" ]
            ]

