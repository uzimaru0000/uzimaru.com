module Model exposing (Model, Msg(..), History(..), init)

import Browser.Dom as Dom
import Command exposing (..)
import Command.Help as HelpCmd
import FileSystem as FS exposing (FileSystem(..))
import Html exposing (Html)
import Json.Decode as JD
import Lazy.Tree.Zipper as Zipper exposing (Zipper)
import Task
import FileSystem exposing (Directory)
import Bytes.Encode as BE
import Utils


type History = History (Zipper FileSystem) String Command

type alias Model =
    { input : String
    , history : List History
    , fileSystem : Zipper FileSystem
    , complement : Maybe (List String)
    }


type Msg
    = NoOp
    | OnInput String
    | OnEnter
    | OnTab
    | OnCommand Command
    | PrevCommand
    | Clear
    | Focus
    | ClickHeader Bool


initFileSystem : FileSystem
initFileSystem =
    Directory_
        { info = { name = "~" }
        , children = 
            [ Directory_
                { info = { name = "bin" }
                , children =
                    [ File_
                        { info = { name = "elm" }
                        , data = BE.encode (BE.string "")
                        }
                    ]
                }
            , Directory_
                { info = { name = "dev" }
                , children = []
                }
            , Directory_
                { info = { name = "usr" }
                , children = []
                }
            , Directory_
                { info = { name = "Users" }
                , children =
                    [ Directory_
                        { info = { name = "uzimaru0000" }
                        , children =
                            [ File_
                                { info = { name = "profile" }
                                , data =
                                    Utils.stringToBytes """## Profile
- name
    - uzimaru0000
- age
    - 22
"""
                                }
                            ]
                        }
                    ]
                }
            ]
        }
        


init : JD.Value -> ( Model, Cmd Msg )
init value =
    let
        initDir =
            value
                |> JD.decodeValue FS.decoder
                |> Result.withDefault initFileSystem
                |> FS.builder
                |> Zipper.fromTree
    in
    ( { input = ""
      , history = [ History initDir "help" (Help <| HelpCmd.Help) ]
      , fileSystem = initDir
      , complement = Nothing
      }
    , Task.attempt (\_ -> NoOp) <| Dom.focus "prompt"
    )
