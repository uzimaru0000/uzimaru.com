module Content exposing (..)

import Json.Decode as Decode exposing (..)
import Json.Decode.Pipeline as Pipeline exposing (..)


type alias Post =
    { title : String
    , data : List String
    , subData : Maybe (List String)
    , contentUrl : String
    , imgUrl : String
    }

postDecoder : Decoder Post
postDecoder =
    Pipeline.decode Post
    |> required "title" Decode.string
    |> required "data" (Decode.list Decode.string)
    |> custom (Decode.maybe <| Decode.field "subData" <| Decode.list Decode.string)
    |> required "contentUrl" Decode.string
    |> required "imgUrl" Decode.string