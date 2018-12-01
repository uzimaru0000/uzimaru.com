module Update exposing (update)

import Browser.Dom
import Model exposing (..)
import Task



-- update


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        OnInput str ->
            ( { model
                | input = model.input ++ str
              }
            , Cmd.none
            )

        OnEnter ->
            ( { model
                | history = model.history ++ [ parseCommand model.input ]
                , input = ""
              }
            , tarminalJumpToBotton "tarminal"
            )

        Clear ->
            ( { model | history = [], input = "" }
            , Cmd.none
            )

        Tick ->
            ( { model | caret = not model.caret }
            , Cmd.none
            )

        Delete ->
            ( { model | input = model.input |> String.dropRight 1 }
            , Cmd.none
            )

        _ ->
            ( model, Cmd.none )


parseCommand : String -> Commands
parseCommand cmd =
    case cmd of
        "whoami" ->
            WhoAmI

        "work" ->
            Work

        "link" ->
            Link

        "help" ->
            Help

        _ ->
            None cmd


tarminalJumpToBotton : String -> Cmd Msg
tarminalJumpToBotton id =
    Browser.Dom.getViewportOf id
        |> Task.andThen (\info -> Browser.Dom.setViewportOf id 0 info.scene.height)
        |> Task.attempt (\_ -> NoOp)
