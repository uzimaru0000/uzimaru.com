module Main exposing (..)

import Html exposing (Html, program, text)
import Model exposing (..)
import Http exposing (getString, send)
import Markdown exposing (toHtml)
import Port exposing (..)


-- view


view : Model -> Html Msg
view model =
    toHtml [] model



-- update


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GetUrl url ->
            ( model, getData <| url ++ "/post/index.md" )

        GetData (Ok str) ->
            ( str, Cmd.none )

        GetData (Err _) ->
            ( model, Cmd.none )

        _ ->
            ( model, Cmd.none )


getData : String -> Cmd Msg
getData url =
    send GetData <|
        getString url



-- main


main : Program Never Model Msg
main =
    program
        { init = ( "hoge", requestUrl () )
        , view = view
        , update = update
        , subscriptions = \_ -> getUrl GetUrl
        }
