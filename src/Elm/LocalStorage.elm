port module LocalStorage exposing (..)

import Json.Encode as JE


port store : JE.Value -> Cmd msg


port fetch : (JE.Value -> msg) -> Sub msg
