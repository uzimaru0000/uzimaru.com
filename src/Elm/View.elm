module View exposing (..)

import Html exposing (Html, text, a, p)
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
    Layout.render Mdl
        model.mdl
        [ Layout.fixedHeader ]
        { header = [ text "" ]
        , drawer = []
        , tabs = ( [], [] )
        , main = [ mainContent model
                 , dialog model
                 ]
        }
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
    Dialog.view []
        [ Dialog.title [] [ text "test" ]
        , Dialog.content []
            [ p [] [ text "dialogTest" ]
            , p [] [ text <| toString model.focusCard ]
            ]
        , Dialog.actions []
            [ Button.render Mdl
                [ 0 ]
                model.mdl
                [ Dialog.closeOn "click"
                , Button.icon
                ]
                [ Icon.i "close" ]
            ]
        ]


card : CardInfo -> Html Msg
card { id, title, imgUrl, content, isActive } =
    Card.view
        [ Options.css "width" "90%"
        , Options.css "margin" "auto"
        , if isActive then
            Elevation.e8
          else
            Elevation.e4
        , Elevation.transition 300
        , Options.onClick NoOp
        , Options.onMouseEnter <| MouseEnter id
        , Options.onMouseLeave <| MouseLeave id
        , Dialog.openOn "click"
        ]
        [ Card.title
            [ Options.css "height" "256px"
            , Options.css "padding" "0"
            , Options.css "background" ("url(" ++ imgUrl ++ ") center / cover")
            , Typo.title
            , Typo.uppercase
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
            [ createList content ]
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
