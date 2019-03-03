port module LocalStorage exposing (fetch, store)

import Json.Decode as JD
import Json.Encode as JE


port store : JE.Value -> Cmd msg


port fetch : (JD.Value -> msg) -> Sub msg
