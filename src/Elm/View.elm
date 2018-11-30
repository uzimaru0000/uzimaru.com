module View exposing (view)

import Dict
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Ev
import Json.Decode as JD
import Model exposing (..)



-- view


view : Model -> Html Msg
view model =
    div
        [ Attr.id "tarminal" ]
        [ model.history
            |> List.map historyView
            |> div []
        , prompt model.input
        ]


prompt : String -> Html Msg
prompt val =
    div []
        [ span [] [ text ">> " ]
        , input
            [ Attr.class "prompt command"
            , Ev.onInput OnInput
            , onKeyDownWithCtrl
                (\ctrl code ->
                    case code of
                        13 ->
                            JD.succeed OnEnter

                        76 ->
                            if ctrl then
                                JD.succeed Clear

                            else
                                JD.fail "not ctrl"

                        _ ->
                            JD.fail "not match key"
                )
            , Attr.value val
            , Attr.autofocus True
            ]
            []
        ]


onKeyDownWithCtrl : (Bool -> Int -> JD.Decoder msg) -> Html.Attribute msg
onKeyDownWithCtrl decoder =
    JD.map2 decoder
        (JD.field "ctrlKey" JD.bool)
        (JD.field "keyCode" JD.int)
        |> JD.andThen identity
        |> Ev.on "keydown"


historyView : Commands -> Html Msg
historyView cmd =
    div []
        [ span [] [ text ">> " ]
        , span [ Attr.class "command" ] [ text <| commandToString cmd ]
        , outputView cmd
        ]


outputView : Commands -> Html Msg
outputView cmd =
    case cmd of
        None str ->
            div []
                [ span []
                    [ text <| "Unknown command " ++ String.pad (String.length str + 2) '"' str
                    ]
                ]

        Help ->
            help

        WhoAmI ->
            whoami

        Work ->
            work

        Link ->
            links


createList : ( String, String ) -> Html Msg
createList ( a, b ) =
    li []
        [ span [] [ text a ]
        , span [] [ text b ]
        ]


help : Html Msg
help =
    let
        info =
            List.map2 Tuple.pair
                ([ Help, WhoAmI, Work, Link ]
                    |> List.map commandToString
                )
                [ "Help about this size."
                , "Who is Uzimaru?"
                , "List works which were made by Uzimaru."
                , "List links which to Uzimaru."
                ]
    in
    div [ Attr.class "help" ]
        [ info
            |> List.map createList
            |> ul [ Attr.class "list" ]
        ]


whoami : Html Msg
whoami =
    let
        info =
            [ ( "Name", "Shuji Oba (uzimaru)" )
            , ( "Age", "20" )
            , ( "Hobby", "Cooking, Programming" )
            , ( "Lines", "Unity, Elm, Golang" )
            ]
    in
    div [ Attr.class "whoami" ]
        [ figure [] [ img [ Attr.src "icon2.png" ] [] ]
        , info
            |> List.map createList
            |> ul [ Attr.class "list" ]
        ]


work : Html Msg
work =
    let
        info =
            [ ( "WeatherApp", "WeatherApp made by Elm.", "https://uzimaru0000.github.io/elm-weather-app" )
            , ( "Sticky", "Sticky note app that can use markdown.", "https://github.com/uzimaru0000/Sticky" )
            , ( "Stock", "Notebook app that can use Markdown.", "https://uzimaru0000.github.io/stock" )
            , ( "VR", "Summary made with VR.", "https://twitter.com/i/moments/912461981851860992" )
            ]
    in
    div [ Attr.class "work" ]
        [ info
            |> List.map
                (\( title, subTitle, url ) ->
                    li []
                        [ a [ Attr.href url, Attr.target "_blink" ] [ text title ]
                        , span [] [ text subTitle ]
                        ]
                )
            |> ul [ Attr.class "list" ]
        ]


links : Html Msg
links =
    div [ Attr.class "links" ]
        []
