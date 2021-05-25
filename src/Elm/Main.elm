module Main exposing (main)

import Browser exposing (..)
import Browser.Events exposing (..)
import Json.Decode as JD
import Model exposing (..)
import Time exposing (..)
import Update exposing (..)
import View exposing (..)
import Command


-- main


main : Program JD.Value Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    [ onClick <| JD.succeed Focus
    , onKeyDownWithCtrl
        (\ctrl code ->
            if ctrl && code == 67 then
                JD.succeed Cancel 
            else
                JD.fail ""
        )
    , Command.subscriptions model.process
        |> Sub.map ProcessMsg
    ] |> Sub.batch


onKeyDownWithCtrl : (Bool -> Int -> JD.Decoder msg) -> Sub msg
onKeyDownWithCtrl decoder =
    JD.map2 decoder
        (JD.field "ctrlKey" JD.bool)
        (JD.field "keyCode" JD.int)
        |> JD.andThen identity
        |> onKeyDown
