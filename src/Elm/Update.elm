module Update exposing (update)

import Model exposing (..)



-- update


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        OnInput str ->
            ( { model
                | input = str
              }
            , Cmd.none
            )

        OnEnter ->
            ( { model
                | history =
                    if String.isEmpty model.input |> not then
                        model.history ++ [ parseCommand model.input ]

                    else
                        model.history
                , input = ""
              }
            , Cmd.none
            )

        Clear ->
            ( { model | history = [], input = "" }
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
