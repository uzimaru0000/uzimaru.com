module Content exposing (..)

import Http exposing (..)
import Json.Decode as Decode exposing (..)
import Json.Decode.Pipeline as Pipeline exposing (..)


type ContentType
    = Normal
    | SubTitle
    | Link


type alias Post =
    { title : String
    , data : List String
    , subData : List String
    , type_ : ContentType
    , contentUrl : String
    , imgUrl : String
    }


convertType : Int -> ContentType
convertType n =
    case n of
        0 -> Normal
        1 -> SubTitle
        2 -> Link
        _ -> Normal

    
postDecoder : Decoder Post
postDecoder =
    Pipeline.decode Post
    |> required "title" Decode.string
    |> required "data" (Decode.list Decode.string)
    |> required "subData" (Decode.list Decode.string)
    |> required "type" typeDecoder
    |> required "contentUrl" Decode.string
    |> required "imgUrl" Decode.string


typeDecoder : Decoder ContentType
typeDecoder =
    Decode.map convertType Decode.int
