module View exposing (view)

import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Ev
import Json.Decode as JD
import Model exposing (..)
import Lazy.Tree.Zipper exposing (Zipper)
import Directory as Dir exposing (Directory(..))


-- view


view : Model -> Html Msg
view model =
    div [ Attr.id "wrapper" ]
        [ header
        , div
            [ Attr.id "tarminal" ]
            [ div [] model.view
            , stdin model.caret model.input model.directory
            ]
        ]


header : Html Msg
header =
    div
        [ Attr.id "header" ]
        [ span [] []
        , span [] []
        , span [] []
        ]


stdin : Bool -> String -> Zipper Directory -> Html Msg
stdin caret val dir =
    div []
        [ Dir.prompt dir
        , input
            [ Attr.id "prompt"
            , Ev.onInput OnInput
            , Attr.value val
            , onKeyDownWithCtrl
                (\ctrl code ->
                    case ( ctrl, code ) of
                        ( True, 76 ) ->
                            JD.succeed Clear

                        ( _, 13 ) ->
                            JD.succeed OnEnter

                        _ ->
                            JD.fail "not matching"
                )
            ]
            []
        , pre [] [ text val ]
        , span []
            [ text <|
                if caret then
                    "|"
                else
                    ""
            ]
        ]


onKeyDownWithCtrl : (Bool -> Int -> JD.Decoder msg) -> Html.Attribute msg
onKeyDownWithCtrl decoder =
    JD.map2 decoder
        (JD.field "ctrlKey" JD.bool)
        (JD.field "keyCode" JD.int)
        |> JD.andThen identity
        |> Ev.on "keydown"
