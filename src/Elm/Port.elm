port module Port exposing (..)


port requestUrl : () -> Cmd msg


port getUrl : (String -> msg) -> Sub msg
