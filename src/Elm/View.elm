module View exposing (..)

import Html exposing (Html, text, a, h4, p)
import Model exposing (..)
import Content exposing (Post)
import Markdown exposing (toHtml)
import Material.Options as Options
import Material.Color as Color
import Material.Scheme as Scheme
import Material.Elevation as Elevation
import Material.Layout as Layout
import Material.Typography as Typo
import Material.Grid as Grid exposing (grid, cell, size, offset, align, Device(..), Align(..))
import Material.Card as Card
import Material.List as Lists
import Material.Button as Button
import Material.Icon as Icon


-- view


view : Model -> Html Msg
view model =
    Options.div []
        [ Layout.render Mdl
            model.mdl
            [ Layout.fixedHeader ]
            { header = [ text "" ]
            , drawer = []
            , tabs = ( [], [] )
            , main = [ mainContent model ]
            }
        , if model.firstModal then
            dialog model
          else
            text ""
        ]
        |> Scheme.topWithScheme Color.Green Color.Indigo


mainContent : Model -> Html Msg
mainContent model =
    grid
        [ Options.css "padding" "4% 8%"
        , Options.css "margin" "auto"
        ]
        (model.contents
            |> List.map (\c -> cell [ size All 4, Grid.stretch ] [ card c ])
        )


dialog : Model -> Html Msg
dialog model =
    Options.div
        [ Options.cs "overLap"
        , if model.focusCard == Nothing then
            Options.cs "hide"
          else
            Options.cs "show"
        ]
        [ grid
            [ Elevation.e4
            , Color.background Color.white
            , Options.cs "window"
            ]
            (case model.focusCard of
                Just c ->
                    [ cell
                        [ size Desktop 11, size Phone 3, size Tablet 7 ]
                        [ Options.span
                            [ Typo.display1
                            , Typo.uppercase
                            ]
                            [ text c.post.title ]
                        ]
                    , cell [ size All 1 ]
                        [ Button.render Mdl
                            [ 0 ]
                            model.mdl
                            [ Button.icon
                            , Options.onClick <| CardFocus Nothing
                            ]
                            [ Icon.i "close" ]
                        ]
                    , cell [ size Desktop 12, size Tablet 8, size Phone 4 ]
                        [ toHtml [] c.content ]
                    ]

                Nothing ->
                    []
            )
        ]


card : CardInfo -> Html Msg
card info =
    Card.view
        [ Options.css "width" "90%"
        , Options.css "margin" "auto"
        , if info.isActive then
            Elevation.e8
          else
            Elevation.e4
        , Elevation.transition 300
        , Options.onClick <| CardFocus (Just info)
        , Options.onMouseEnter <| MouseEnter info.id
        , Options.onMouseLeave <| MouseLeave info.id
        ]
        [ Card.title
            [ Options.css "height" "256px"
            , Options.css "padding" "0"
            , Options.css "background" ("url(" ++ info.post.imgUrl ++ ") center / cover") |> Options.when (String.isEmpty info.post.imgUrl |> not)
            , Typo.title
            , Typo.uppercase
            ]
            [ Card.head
                [ Color.text Color.white
                , Options.scrim 0.6
                , Options.css "padding" "16px"
                , Options.css "width" "100%"
                ]
                [ text info.post.title ]
            ]
        , Card.text
            []
            [ createList info.post ]
        ]


createList : Post -> Html Msg
createList post =
    Lists.ul []
        (case post.subData of
            Nothing ->
                List.map normalList post.data

            Just sub ->
                List.map2 (,) post.data sub
                    |> List.map subTitleList
        )


listContent : List (Html msg) -> Html msg
listContent content =
    Lists.content []
        ([ Lists.icon "keyboard_arrow_right" [] ] ++ content)


normalList : String -> Html Msg
normalList title =
    Lists.li []
        [ listContent [ text title ] ]


subTitleList : ( String, String ) -> Html Msg
subTitleList ( title, subTitle ) =
    Lists.li [ Lists.withSubtitle ]
        [ listContent
            [ text title
            , Lists.subtitle [] [ text subTitle ]
            ]
        ]
