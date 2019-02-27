module Model exposing (..)

import Browser.Dom
import Task
import Directory as Dir exposing (Directory(..))
import Lazy.Tree.Zipper as Zipper exposing (Zipper)
import Html exposing (Html)
import Command exposing (..)


type alias Model =
    { input : String
    , history : List Commands
    , view : List (Html Msg)
    , caret : Bool
    , directory : Zipper Directory
    }


type Msg
    = NoOp
    | Tick
    | OnInput String
    | OnEnter
    | OnCommand Commands
    | Focus
    | Clear


init : () -> ( Model, Cmd Msg )
init _ =
    ( { input = ""
      , history = []
      , view = []
      , caret = True
      , directory =
            Directory { name = "~" }
                [ Directory { name = "dev" }
                    []
                , Directory { name = "usr" }
                    []
                , Directory { name = "bin" }
                    []
                , Directory { name = "Users" }
                    [ Directory { name = "uzimaru0000" } [] ]
                ]
                |> Dir.builder
                |> Zipper.fromTree
      }
    , [ Task.attempt (\_ -> NoOp) <| Browser.Dom.focus "prompt"
      , Task.perform identity (Task.succeed <| OnCommand ( Help, [] ))
      ]
        |> Cmd.batch
    )
