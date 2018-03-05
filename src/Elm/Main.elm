module Main exposing (..)

import Html exposing (Html, program, text, div, header)
import Port exposing (..)
import Update exposing (..)
import Model exposing (..)
import View exposing (..)
import Material

-- main

main : Program Never Model Msg
main =
    program
        { init = ( Model [] Nothing False Material.model, requestUrl () )
        , view = view
        , update = update
        , subscriptions = \_ -> getUrl GetHost
        }
