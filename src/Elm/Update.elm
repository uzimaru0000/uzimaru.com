module Update exposing (update)

import Browser.Dom
import Command as Cmd exposing (Command(..))
import Directory as Dir exposing (Directory(..))
import Lazy.Tree.Zipper as Zipper exposing (Zipper)
import LocalStorage as LS
import Model exposing (..)
import Parser
import Task
import Html.Attributes exposing (dir)



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
            (parseCommand model.input
                |> OnCommand
                |> update
            )
                model

        OnCommand cmd ->
            Cmd.run cmd model.directory
                |> (\(result, effect) ->
                    let
                        dir = Result.withDefault model.directory result
                        cmd_ =
                            case result of
                                Ok _ -> cmd
                                Err err -> Cmd.CmdErr err
                    in
                    ( { model
                        | input = ""
                        , directory = dir
                        , history =
                            model.history
                                ++ [ History model.directory model.input cmd_ ]
                    }
                    , [ tarminalJumpToBotton "tarminal"
                      , focus
                      , effect
                      ]
                          |> Cmd.batch
                    )
                   )

        PrevCommand ->
            let
                prevCmd =
                    model.history
                        |> List.reverse
                        |> List.head
            in
            ( { model
                | input =
                    prevCmd
                        |> Maybe.map (\(History _ str _) -> str)
                        |> Maybe.withDefault ""
              }
            , Cmd.none
            )

        Clear ->
            ( { model | history = [] }
            , focus
            )

        Focus ->
            (model, focus)

        _ ->
            ( model, Cmd.none )


parseCommand : String -> Command
parseCommand str =
    case Parser.run Cmd.parser str of
        Ok cmd ->
            cmd

        Err _ ->
            Cmd.CmdErr <| "Unknown command: " ++ str 


tarminalJumpToBotton : String -> Cmd Msg
tarminalJumpToBotton id =
    Browser.Dom.getViewportOf id
        |> Task.andThen (\info -> Browser.Dom.setViewportOf id 0 info.scene.height)
        |> Task.attempt (\_ -> NoOp)

focus : Cmd Msg
focus =
    Task.attempt (\_ -> NoOp) <| Browser.Dom.focus "prompt"
