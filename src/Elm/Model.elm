module Model exposing (Model, Msg(..), init)

import Browser.Dom
import Command exposing (..)
import Directory as Dir exposing (Directory(..))
import Html exposing (Html)
import Json.Decode as JD
import Lazy.Tree.Zipper as Zipper exposing (Zipper)
import Task


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
      }
    , [ Task.attempt (\_ -> NoOp) <| Browser.Dom.focus "prompt"
      , Task.perform identity (Task.succeed <| OnCommand ( Help, [] ))
      ]
        |> Cmd.batch
    )
