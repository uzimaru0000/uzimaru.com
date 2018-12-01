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
    [ onKeyDownWithCtrl
        (\ctrl code ->
            case code of
                13 ->
                    JD.succeed OnEnter

                76 ->
                    if ctrl then
                        JD.succeed Clear

                    else
                        JD.fail "not ctrl"

                8 ->
                    JD.succeed Delete

                _ ->
                    JD.fail "not match key"
        )
    , Time.every 500 (always Tick)
    , onKeyDownCode OnInput
    ]
        |> Sub.batch


onKeyDownWithCtrl : (Bool -> Int -> JD.Decoder msg) -> Sub msg
onKeyDownWithCtrl decoder =
    JD.map2 decoder
        (JD.field "ctrlKey" JD.bool)
        (JD.field "keyCode" JD.int)
        |> JD.andThen identity
        |> Browser.Events.onKeyDown


onKeyDownCode : (String -> msg) -> Sub msg
onKeyDownCode msg =
    let
        decoder key =
            if key |> String.length |> Debug.log "" |> (/=) 1 then
                JD.fail "Not alpha-num"

            else
                JD.succeed key
    in
    JD.field "key" JD.string
        |> JD.andThen decoder
        |> JD.map msg
        |> Browser.Events.onKeyDown
