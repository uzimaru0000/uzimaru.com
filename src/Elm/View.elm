module View exposing (..)

import Html exposing (Html, text, a)
import Html.Attributes exposing (href)
import Model exposing (..)
import Material.Options as Options
import Material.Color as Color
import Material.Scheme as Scheme
import Material.Elevation as Elevation
import Material.Layout as Layout
import Material.Grid as Grid exposing (grid, cell, size, offset, align, Device(..), Align(..))
import Material.Card as Card
import Material.List as Lists


-- view


view : Model -> Html Msg
view model =
    Layout.render Mdl
        model.mdl
        [ Layout.fixedHeader ]
        { header = [ text "" ]
        , drawer = []
        , tabs = ( [], [] )
        , main = [ mainContent model ]
        }
        |> Scheme.topWithScheme Color.LightBlue Color.Cyan


mainContent : Model -> Html Msg
mainContent model =
    grid
        [ Options.css "padding" "4% 8%"
        , Options.css "margin" "auto"
        ]
        [ cell [ size All 4 ]
            [ card "Works" (Color.color Color.Yellow Color.S500) "" <|
                Lists.ul [] ([ "Hoge", "Foo", "Huga" ] |> List.map normalList)
            ]
        , cell [ size All 4 ]
            [ card "About me" (Color.color Color.LightGreen Color.S500) "" <|
                Lists.ul [] ([ ( "Name", "Uzimaru" ), ( "Age", "19" ), ( "Skill", "Unity, Elm" ) ] |> List.map subTitleList)
            ]
        , cell [ size All 4 ]
            [ card "Links" (Color.color Color.Red Color.S500) "" <|
                Lists.ul [] ([ ("GitHub", "#"), ("Twitter", "#"), ("Facebook", "#") ] |> List.map linkList)
            ]
        ]


card : String -> Color.Color -> String -> Html Msg -> Html Msg
card title bgColor imgUrl content =
    Card.view
        [ Options.css "width" "90%"
        , Options.css "margin" "auto"
        , Elevation.e4
        , Options.onClick NoOp
        ]
        [ Card.title
            [ Color.background bgColor
            , Options.css "height" "256px"
            , Options.css "padding" "0"
            , Options.css "background" ("url(./Assets/dog.jpg) center / cover")
            ]
            [ Card.head
                [ Color.text Color.white
                , Options.scrim 0.6
                , Options.css "padding" "16px"
                , Options.css "width" "100%"
                ]
                [ text title ]
            ]
        , Card.text
            []
            [ content
            ]
        ]


listContent : List (Html msg) -> Html msg
listContent content =
    Lists.content []
        ([ Lists.icon "keyboard_arrow_right" [] ] ++ content)


normalList : String -> Html msg
normalList title =
    Lists.li []
        [ listContent [ text title ] ]


subTitleList : ( String, String ) -> Html msg
subTitleList ( title, subTitle ) =
    Lists.li [ Lists.withSubtitle ]
        [ listContent
            [ text title
            , Lists.subtitle [] [ text subTitle ]
            ]
        ]


linkList : ( String, String ) -> Html msg
linkList ( title, url ) =
    Lists.li []
        [ listContent
            [ a [ href url ] [ text title ] ]
        ]
