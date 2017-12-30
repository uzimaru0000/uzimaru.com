module Main exposing (..)

import Html exposing (Html, program, text)
import Model exposing (..)


-- view


view : Model -> Html Msg
view model =
    text "hoge"



-- update


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        _ ->
            ( model, Cmd.none )



-- main


main : Program Never Model Msg
main =
    program
        { init = "hoge" ! []
        , view = view
        , update = update
        , subscriptions = always Sub.none
        }
