module View exposing (view)

import Command exposing (Command(..))
import Directory as Dir exposing (Directory(..))
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Ev
import Json.Decode as JD
import Lazy.Tree.Zipper exposing (Zipper)
import Model exposing (..)



-- view


px : String -> String
px str =
    str ++ "px"


view : Model -> Html Msg
view model =
    div [ Attr.id "wrapper" ]
        [ div
            [ Attr.id "window"
            , Attr.style "left" <| (px << String.fromFloat << Tuple.first) model.windowPos
            , Attr.style "top" <| (px << String.fromFloat << Tuple.second) model.windowPos
            ]
          <|
            [ header ]
                ++ (history <|
                        List.map2 Tuple.pair model.rowCmds model.history
                   )
                ++ [ div
                        [ Attr.id "tarminal" ]
                        [ stdin model.caret model.input model.directory
                        ]
                   ]
        ]


header : Html Msg
header =
    div
        [ Attr.id "header"
        , Ev.onMouseDown <| ClickHeader True
        , Ev.onMouseUp <| ClickHeader False
        ]
        [ span [] []
        , span [] []
        , span [] []
        ]


history : List ( String, Command ) -> List (Html Msg)
history =
    List.map historyView


historyView : ( String, Command ) -> Html Msg
historyView ( row, cmd ) =
    div
        []
        [ pre [] [ text row ]
        , Command.view cmd
            |> Html.map OnCommand
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
