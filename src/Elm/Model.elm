module Model exposing (Model, Msg(..), init)

import Browser.Dom as Dom
import Command exposing (..)
import Command.Help as HelpCmd
import Directory as Dir exposing (Directory(..))
import Html exposing (Html)
import Json.Decode as JD
import Lazy.Tree.Zipper as Zipper exposing (Zipper)
import Task


type alias Model =
    { input : String
    , history : List Command
    , view : List (Html Msg)
    , caret : Bool
    , directory : Zipper Directory
    , isClickHeader : Bool
    , windowPos : ( Float, Float )
    }


type Msg
    = NoOp
    | Tick
    | OnInput String
    | OnEnter
    | OnCommand Command
    | Focus
    | Clear
    | GetWindow (Result Dom.Error Dom.Element)
    | ClickHeader Bool
    | MoveMouse ( Float, Float )


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
      , history = []
      , view = []
      , caret = True
      , directory =
            value
                |> JD.decodeValue Dir.decoder
                |> Result.withDefault initDirectory
                |> Dir.builder
                |> Zipper.fromTree
      , isClickHeader = False
      , windowPos = ( 0, 0 )
      }
    , [ Task.attempt (\_ -> NoOp) <| Dom.focus "prompt"
      , Task.perform identity (Task.succeed <| OnCommand (Help <| HelpCmd.Help { command = Nothing }))
      , Task.attempt GetWindow <| Dom.getElement "window"
      ]
        |> Cmd.batch
    )
