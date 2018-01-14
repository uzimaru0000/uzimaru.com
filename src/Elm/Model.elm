module Model exposing (..)

import Http


-- Model


type alias Model =
    String



-- Message


type Msg
    = NoOp
    | GetUrl String
    | GetData (Result Http.Error String)
