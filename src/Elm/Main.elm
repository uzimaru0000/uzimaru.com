module Main exposing (main)

import Browser exposing (..)
import Browser.Events exposing (..)
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
        , subscriptions = always Sub.none
        }
