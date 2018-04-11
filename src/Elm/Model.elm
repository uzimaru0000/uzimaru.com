module Model exposing (..)

import Content exposing (Post)
import Http
import Material


-- Model


type alias CardInfo =
    { id : Int
    , post : Post
    , content : String
    , isActive : Bool
    }


type alias Model =
    { contents : List CardInfo
    , focusCard : Maybe CardInfo
    , firstModal : Bool
    , mdl : Material.Model
    }



-- Message


type Msg
    = NoOp
    | GetHost String
    | GetPost String Int (Result Http.Error Post)
    | GetContent Int (Result Http.Error String)
    | MouseEnter Int
    | MouseLeave Int
    | CardFocus (Maybe CardInfo)
    | Mdl (Material.Msg Msg)
