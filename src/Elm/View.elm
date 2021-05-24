module View exposing (view)

import Command exposing (Command(..))
import FileSystem as FS exposing (FileSystem(..))
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Ev
import Json.Decode as JD
import Lazy.Tree.Zipper as Zipper exposing (Zipper)
import Model exposing (..)
import CustomElement exposing (..)
import Command.State as State exposing (ProcState(..))



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
                        (history model.history) ++
                        [ case model.process of
                            Command.Stay -> stdin model.input model.fileSystem
                            _ -> Command.view model.process |> Html.map ProcessMsg
                        ]
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
        (\(History dir raw state) ->
            div
                []
                [ prompt <| FS.pwd dir
                , span [] [ text raw ]
                , case state of
                    State.Running _ -> text ""
                    State.Error _ err -> div [] [ text err ]
                    State.Exit p -> Command.view p |> Html.map ProcessMsg
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


stdin : String -> Zipper FileSystem -> Html Msg
stdin val dir =
    div []
        [ FS.pwd dir 
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
                        
                        ( _, 9 ) ->
                            JD.succeed OnTab

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
        |> JD.map (\x -> (x, True))
        |> Ev.preventDefaultOn "keydown"
