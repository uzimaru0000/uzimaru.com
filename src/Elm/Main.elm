module Main exposing (..)

import Html exposing (Html, program, text, div, header)
import Model exposing (..)
import View exposing (view)
import Http exposing (getString, send)
import Markdown exposing (toHtml)
import Date exposing (..)
import Port exposing (..)
import Material


-- update


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GetUrl url ->
            ( { model | url = url }, getData <| url ++ "/post/index.md" )

        GetData (Ok str) ->
            let
                newContent =
                    Content "" str (Date.fromTime 0)
            in
                ( { model | content = newContent }, Cmd.none )

        GetData (Err _) ->
            ( model, Cmd.none )

        Mdl msg_ ->
            Material.update Mdl msg_ model

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
        { init = ( Model "" (Content "" "" <| Date.fromTime 0) Material.model, Cmd.none )
        , view = view
        , update = update
        , subscriptions = \_ -> getUrl GetUrl
        }
