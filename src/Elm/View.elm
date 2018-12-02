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
    div [ Attr.id "wrapper" ]
        [ header
        , div
            [ Attr.id "tarminal" ]
            [ model.history
                |> List.map historyView
                |> div []
            , prompt model.caret model.input
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


prompt : Bool -> String -> Html Msg
prompt caret val =
    div []
        [ span [] [ text "$ " ]
        , pre []
            [ val
                |> text
            ]
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


historyView : Commands -> Html Msg
historyView cmd =
    div []
        [ span [] [ text "$ " ]
        , span [ Attr.class "command" ] [ text <| commandToString cmd ]
        , outputView cmd
        ]


outputView : Commands -> Html Msg
outputView cmd =
    case cmd of
        None str ->
            div []
                [ span
                    [ Attr.class "glitch"
                    , Attr.attribute "text-node" <|
                        if String.isEmpty str then
                            ""

                        else
                            "Unknown command "
                                ++ String.pad (String.length str + 2) '"' str
                    ]
                    [ text <|
                        if String.isEmpty str then
                            ""

                        else
                            "Unknown command "
                                ++ String.pad (String.length str + 2) '"' str
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
                [ Help, WhoAmI, Work, Link ]
                [ "Help about this site."
                , "Who is me?"
                , "List works which were made by me."
                , "List links which to me."
                ]
    in
    div [ Attr.class "help" ]
        [ info
            |> List.map
                (\( cmd, b ) ->
                    li []
                        [ a [ Ev.onClick <| OnCommand cmd ] [ text <| commandToString cmd ]
                        , span [] [ text b ]
                        ]
                )
            |> ul [ Attr.class "list" ]
        ]


whoami : Html Msg
whoami =
    let
        info =
            [ ( "Name", "Shuji Oba (uzimaru)" )
            , ( "Age", "20" )
            , ( "Hobby", "Cooking, Programming" )
            , ( "Likes", "Unity, Elm, Golang" )
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
    let
        info =
            [ ( "GitHub", "https://github.com/uzimaru0000" )
            , ( "Twitter", "https://twitter.com/uzimaru0601" )
            , ( "Facebook", "https://www.facebook.com/shuji.oba.1" )
            , ( "Qiita", "https://qiita.com/uzimaru0000" )
            , ( "Blog", "http://uzimaru0601.hatenablog.com" )
            ]
    in
    div [ Attr.class "links" ]
        [ info
            |> List.map
                (\( title, url ) ->
                    li []
                        [ a [ Attr.href url, Attr.target "_blink" ] [ text title ]
                        ]
                )
            |> ul [ Attr.class "list" ]
        ]
