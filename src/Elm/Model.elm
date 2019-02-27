module Model exposing (..)

import Browser.Dom
import Task
import Directory as Dir exposing (Directory(..))
import Lazy.Tree.Zipper as Zipper exposing (Zipper)


type alias Model =
    { input : String
    , history : List Commands
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


type Command
    = None String
    | Help
    | WhoAmI
    | Work
    | Link
    | List
    | MakeDir
    | Touch
    | ChangeDir
    | Remove


type alias Args =
    List String


type alias Commands =
    ( Command, Args )


init : () -> ( Model, Cmd Msg )
init _ =
    ( { input = ""
      , history = [ ( Help, [] ) ]
      , caret = True
      , directory =
            Directory { name = "/" }
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
    , Task.attempt (\_ -> NoOp) <| Browser.Dom.focus "prompt"
    )


commandToString : Command -> String
commandToString cmd =
    case cmd of
        None str ->
            str

        Help ->
            "help"

        WhoAmI ->
            "whoami"

        Work ->
            "work"

        Link ->
            "link"

        List ->
            "ls"

        MakeDir ->
            "mkdir"

        Touch ->
            "touch"

        ChangeDir ->
            "cd"

        Remove ->
            "rm"
