module View exposing (..)

import Html exposing (Html, text, a, h4, p)
import Html.Attributes exposing (href)
import Model exposing (..)
import Material.Options as Options
import Material.Color as Color
import Material.Scheme as Scheme
import Material.Elevation as Elevation
import Material.Layout as Layout
import Material.Typography as Typo
import Material.Grid as Grid exposing (grid, cell, size, offset, align, Device(..), Align(..))
import Material.Card as Card
import Material.List as Lists
import Material.Dialog as Dialog
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
            , main =
                [ mainContent model ]
            }
        , if model.firstModal then
            dialog model
          else
            text ""
        ]
        |> Scheme.topWithScheme Color.LightBlue Color.Cyan


mainContent : Model -> Html Msg
mainContent model =
    grid
        [ Options.css "padding" "4% 8%"
        , Options.css "margin" "auto"
        ]
        (model.contents
            |> List.map (\c -> cell [ size All 4 ] [ card c ])
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
                        [ size All 6 ]
                        [ Options.span [ Typo.display3, Typo.center, Color.text Color.black ] [ text "Title" ] ]
                    , cell [ size All 1, offset All 5 ]
                        [ Button.render Mdl
                            [ 0 ]
                            model.mdl
                            [ Button.icon
                            , Options.onClick <| CardFocus Nothing
                            ]
                            [ Icon.i "close" ]
                        ]
                    , cell [ size All 12 ]
                        [ text "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum." ]
                    ]

                -- [ cell [ size All 4, Color.background (Color.color Color.Green Color.S500) ]
                --     [ h4 [] [ text "Cell 1" ]
                --     ]
                -- , cell [ offset All 2, size All 4, Color.background (Color.color Color.Green Color.S500) ]
                --     [ h4 [] [ text "Cell 2" ]
                --     , p [] [ text "This cell is offset by 2" ]
                --     ]
                -- , cell [ size All 6, Color.background (Color.color Color.Green Color.S500) ]
                --     [ h4 [] [ text "Cell 3" ]
                --     ]
                -- , cell [ size All 12, Color.background (Color.color Color.Green Color.S500), Grid.stretch ]
                --     [ h4 [] [ text "Cell 4" ]
                --     , p [] [ text "Size varies with device" ]
                --     ]
                -- ]
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
            , Options.css "background" ("url(" ++ info.imgUrl ++ ") center / cover")
            , Typo.title
            , Typo.uppercase
            ]
            [ Card.head
                [ Color.text Color.white
                , Options.scrim 0.6
                , Options.css "padding" "16px"
                , Options.css "width" "100%"
                ]
                [ text info.title ]
            ]
        , Card.text
            []
            [ createList info.content ]
        ]


createList : Content -> Html Msg
createList { data, subData, type_ } =
    Lists.ul []
        (case type_ of
            Normal ->
                List.map normalList data

            SubTitle ->
                List.map2 (,) data subData
                    |> List.map subTitleList

            Link ->
                List.map2 (,) data subData
                    |> List.map linkList
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


linkList : ( String, String ) -> Html Msg
linkList ( title, url ) =
    Lists.li []
        [ listContent
            [ a [ href url ] [ text title ] ]
        ]
