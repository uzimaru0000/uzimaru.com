module Model exposing (Model, Msg(..), init)

import Browser.Dom as Dom
import Command exposing (..)
import Directory as Dir exposing (Directory(..))
import Html exposing (Html)
import Lazy.Tree.Zipper as Zipper exposing (Zipper)
import Task


type alias Model =
    { input : String
    , history : List Commands
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
    | OnCommand Commands
    | Focus
    | Clear
    | GetWrapper Dom.Element (Result Dom.Error Dom.Element)
    | GetWindow (Result Dom.Error Dom.Element)
    | ClickHeader Bool
    | MoveMouse ( Float, Float )


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
      , isClickHeader = False
      , windowPos = ( 0, 0 )
      }
    , [ Task.attempt (\_ -> NoOp) <| Dom.focus "prompt"
      , Task.perform identity (Task.succeed <| OnCommand ( Help, [] ))
      , Task.attempt GetWindow <| Dom.getElement "window"
      ]
        |> Cmd.batch
    )
