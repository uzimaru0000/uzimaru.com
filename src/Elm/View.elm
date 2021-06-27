module View exposing (view)

import Command exposing (Command(..), Process(..))
import Command.State as State exposing (ProcState(..))
import CustomElement exposing (..)
import FileSystem as FS exposing (FileSystem(..))
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
    div [ Attr.class "flex items-center justify-center h-screen" ]
        [ div
            [ Attr.class "h-4/5 w-4/5" ]
            [ div
                [ Attr.class "bg-gray rounded-t-2xl p-2 pl-4" ]
                [ span [ Attr.class "bg-red mr-2 rounded-full inline-block w-4 h-4" ] []
                , span [ Attr.class "bg-yellow mr-2 rounded-full inline-block w-4 h-4" ] []
                , span [ Attr.class "bg-green mr-2 rounded-full inline-block w-4 h-4" ] []
                ]
            , div
                [ Attr.id "tarminal"
                , Attr.class "bg-black rounded-b-2xl text-lightGreen p-8 font-sans text-base h-full overflow-y-scroll"
                ]
              <|
                if Command.isFullScreen model.process then
                    [ Command.view model.process |> Html.map ProcessMsg
                    ]

                else
                    history model.history
                        ++ [ if model.process == Stay then
                                stdin model.input model.fileSystem
                             else
                                stdinDummy model.input model.fileSystem
                           , Command.view model.process |> Html.map ProcessMsg
                           ]
            ]
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
                    State.Running _ ->
                        text ""

                    State.Error _ err ->
                        div [] [ text err ]

                    State.Exit p ->
                        if Command.isFullScreen p then
                            text ""

                        else
                            Command.view p |> Html.map ProcessMsg
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


stdinDummy : String -> Zipper FileSystem -> Html msg
stdinDummy val dir =
    div []
        [ FS.pwd dir
            |> prompt
        , span [] [ text val ]
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
            ]
            []
        ]


onKeyDownWithCtrl : (Bool -> Int -> JD.Decoder msg) -> Html.Attribute msg
onKeyDownWithCtrl decoder =
    JD.map2 decoder
        (JD.field "ctrlKey" JD.bool)
        (JD.field "keyCode" JD.int)
        |> JD.andThen identity
        |> JD.map (\x -> ( x, True ))
        |> Ev.preventDefaultOn "keydown"
