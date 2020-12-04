module View exposing (view)

import Command exposing (Command(..))
import Directory as Dir exposing (Directory(..))
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Ev
import Json.Decode as JD
import Lazy.Tree.Zipper as Zipper exposing (Zipper)
import Model exposing (..)
import CustomElement exposing (..)



-- view


px : String -> String
px str =
    str ++ "px"


view : Model -> Html Msg
view model =
    div [ Attr.id "wrapper" ]
        [ div
            [ Attr.id "window" ]
                [ header
                , div
                    [ Attr.id "tarminal" ] <|
                    (history model.history) ++ [ stdin model.input model.directory ]
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


history : List History -> List (Html Msg)
history =
    List.map
        (\(History dir raw cmd) ->
            div
                []
                [ prompt dir
                , span [] [ text raw ]
                , Command.view cmd
                    |> Html.map OnCommand
                ]
        )

prompt : String -> Html msg
prompt dir =
    span []
        [ [ "[ "
          , dir 
          , " ]"
          , " $ "
          ]
            |> String.join ""
            |> text
        ]


stdin : String -> Zipper Directory -> Html Msg
stdin val dir =
    div []
        [ Dir.pwd dir 
            |> prompt
        , terminalInput
            [ Attr.value val
            , Ev.onInput OnInput
            , Attr.id "prompt"
            , onKeyDownWithCtrl
                (\ctrl code ->
                    case ( ctrl, code ) of
                        ( True, 76 ) ->
                            JD.succeed Clear

                        ( _, 13 ) ->
                            JD.succeed OnEnter

                        ( _, 38 ) ->
                            JD.succeed PrevCommand

                        _ ->
                            JD.fail "not matching"
                )
            ] []
        ]


onKeyDownWithCtrl : (Bool -> Int -> JD.Decoder msg) -> Html.Attribute msg
onKeyDownWithCtrl decoder =
    JD.map2 decoder
        (JD.field "ctrlKey" JD.bool)
        (JD.field "keyCode" JD.int)
        |> JD.andThen identity
        |> Ev.on "keydown"
