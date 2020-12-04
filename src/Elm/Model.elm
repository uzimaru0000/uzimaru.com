module Model exposing (Model, Msg(..), History(..), init)

import Browser.Dom as Dom
import Command exposing (..)
import Command.Help as HelpCmd
import Directory as Dir exposing (Directory(..))
import Html exposing (Html)
import Json.Decode as JD
import Lazy.Tree.Zipper as Zipper exposing (Zipper)
import Task


type History = History String String Command

type alias Model =
    { input : String
    , history : List History
    , directory : Zipper Directory
    }


type Msg
    = NoOp
    | OnInput String
    | OnEnter
    | OnCommand Command
    | PrevCommand
    | Clear
    | Focus
    | ClickHeader Bool


initDirectory : Directory
initDirectory =
    Directory { name = "/" }
        [ Directory { name = "bin" }
            [ File { name = "elm" }
            ]
        , Directory { name = "dev" }
            []
        , Directory { name = "usr" }
            []
        , Directory { name = "Users" }
            [ Directory { name = "uzimaru0000" }
                []
            ]
        ]


init : JD.Value -> ( Model, Cmd Msg )
init value =
    ( { input = ""
      , history = [ History "/" "help" (Help <| HelpCmd.Help) ]
      , directory =
            value
                |> JD.decodeValue Dir.decoder
                |> Result.withDefault initDirectory
                |> Dir.builder
                |> Zipper.fromTree
      }
    , Task.attempt (\_ -> NoOp) <| Dom.focus "prompt"
    )
