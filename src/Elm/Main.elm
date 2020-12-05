module Main exposing (main)

import Browser exposing (..)
import Browser.Events exposing (..)
import Json.Decode as JD
import Model exposing (..)
import Time exposing (..)
import Update exposing (..)
import View exposing (..)


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
    onClick <| JD.succeed Focus
