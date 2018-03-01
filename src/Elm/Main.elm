module Main exposing (..)

import Html exposing (Html, program, text, div, header)
import Model exposing (..)
import View exposing (..)
import Material


-- update


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        MouseEnter id ->
            { model | contents = List.map (changeCardState id True) model.contents } ! []
        
        MouseLeave id ->
            { model | contents = List.map (changeCardState id False) model.contents } ! []

        CardFocus info ->
            { model | focusCard = info, firstModal = True } ! []

        Mdl msg_ ->
            Material.update Mdl msg_ model

        _ ->
            model ! []


changeCardState : Int -> Bool -> CardInfo -> CardInfo
changeCardState id state info =
    if info.id == id then
        { info | isActive = state }
    else
        info



-- main


contentData : List CardInfo
contentData =
    [ { id = 0
      , title = "Works"
      , imgUrl = ""
      , content = Content [ "Hoge", "Foo", "Huga" ] [] Normal
      , isActive = False
      }
    , { id = 1
      , title = "About Me"
      , imgUrl = "assets/icon2.png"
      , content = Content [ "Name", "Age", "Skill" ] [ "Uzimaru", "19", "Unity, Elm" ] SubTitle
      , isActive = False
      }
    , { id = 2
      , title = "Links"
      , imgUrl = ""
      , content = Content [ "GitHub", "Twitter", "Facebook" ] [ "#", "#", "#" ] Link
      , isActive = False
      }
    ]


main : Program Never Model Msg
main =
    program
        { init = ( Model contentData Nothing False Material.model, Cmd.none )
        , view = view
        , update = update
        , subscriptions = always Sub.none
        }
