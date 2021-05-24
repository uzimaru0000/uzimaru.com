module Model exposing (Model, Msg(..), History(..), init)

import Browser.Dom as Dom
import Command exposing (..)
import Command.Help as HelpCmd
import FileSystem as FS exposing (FileSystem(..))
import Json.Decode as JD
import Lazy.Tree.Zipper as Zipper exposing (Zipper)
import Task
import Bytes.Encode as BE
import Utils
import Command.State exposing (ProcState)


type History = History (Zipper FileSystem) String (ProcState Process)

type alias Model =
    { input : String
    , history : List History
    , fileSystem : Zipper FileSystem
    , complement : Maybe (List String)
    , process : Process
    }


type Msg
    = NoOp
    | OnInput String
    | OnEnter
    | OnTab
    | ProcessMsg ProcessMsg
    | RunProcess (ProcState Process)
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
            
        (helpProc, effect) = Command.init (Command.Help HelpCmd.Help) initDir
    in
    ( { input = ""
      , history = [ History initDir "help" helpProc ]
      , fileSystem = initDir
      , complement = Nothing
      , process = Stay
      }
    , [ Task.attempt (\_ -> NoOp) <| Dom.focus "prompt"
      , effect |> Cmd.map ProcessMsg
      ] |> Cmd.batch
    )
