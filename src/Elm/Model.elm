module Model exposing (..)

import Http
import Date exposing (Date)
import Material


-- Model


type alias Content =
    { title : String
    , content : String
    , date : Date
    }

type alias Model =
    { url : String
    , content : Content
    , mdl : Material.Model
    }



-- Message


type Msg
    = NoOp
    | GetUrl String
    | GetData (Result Http.Error String)
    | Mdl (Material.Msg Msg)
