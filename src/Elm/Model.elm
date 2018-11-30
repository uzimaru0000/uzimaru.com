module Model exposing (Commands(..), Model, Msg(..), commandToString, init)


type alias Model =
    { input : String
    , history : List Commands
    }


type Msg
    = NoOp
    | OnInput String
    | OnEnter
    | Clear


type Commands
    = None String
    | Help
    | WhoAmI
    | Work
    | Link


init : () -> ( Model, Cmd Msg )
init _ =
    ( { input = ""
      , history = [ Help ]
      }
    , Cmd.none
    )


commandToString : Commands -> String
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
