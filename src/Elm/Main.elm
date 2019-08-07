module Main exposing (main)

import Browser exposing (..)
import Browser.Events exposing (..)
import Json.Decode as JD
import Model exposing (..)
import Time exposing (..)
import Update exposing (..)
import View exposing (..)



-- main


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    [ Time.every 500 (always Tick)
    , onClick <| JD.succeed Focus
    , if model.isClickHeader then
        JD.map2 Tuple.pair
            (JD.field "movementX" JD.float)
            (JD.field "movementY" JD.float)
            |> JD.map MoveMouse
            |> onMouseMove

      else
        Sub.none
    ]
        |> Sub.batch
