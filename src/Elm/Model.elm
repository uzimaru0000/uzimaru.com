module Model exposing (..)

import Html exposing (Html)
import Material


-- Model


type alias CardInfo =
    { id : Int
    , title : String
    , imgUrl : String
    , content : Content
    , isActive : Bool
    }


type ContentType
    = Normal
    | SubTitle
    | Link


type alias Content =
    { data : List String
    , subData : List String
    , type_ : ContentType
    }


type alias Model =
    { contents : List CardInfo
    , focusCard : Maybe CardInfo
    , mdl : Material.Model
    }



-- Message


type Msg
    = NoOp
    | MouseEnter Int
    | MouseLeave Int
    | CardForcus CardInfo
    | Mdl (Material.Msg Msg)
