module Update exposing (update)

import Browser.Dom
import Command as Cmd exposing (Command(..))
import Directory as Dir exposing (Directory(..))
import Lazy.Tree.Zipper as Zipper exposing (Zipper)
import LocalStorage as LS
import Model exposing (..)
import Parser
import Task



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
            ( { model
                | input = ""
                , history =
                    model.history
                        ++ [ History (Dir.pwd model.directory) model.input cmd ]
              }
            , [ tarminalJumpToBotton "tarminal"
              , focus
              , Cmd.run cmd
              , model.directory
                    |> Zipper.getTree
                    |> Dir.dismantlers
                    |> Dir.encoder
                    |> LS.store
              ]
                |> Cmd.batch
            )

        PrevCommand ->
            let
                prevCmd = List.head model.history
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
            ( { model | history = [], input = "" }
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
            Cmd.CmdErr <| Cmd.UnknownCommand str 


tarminalJumpToBotton : String -> Cmd Msg
tarminalJumpToBotton id =
    Browser.Dom.getViewportOf id
        |> Task.andThen (\info -> Browser.Dom.setViewportOf id 0 info.scene.height)
        |> Task.attempt (\_ -> NoOp)

focus : Cmd Msg
focus =
    Task.attempt (\_ -> NoOp) <| Browser.Dom.focus "prompt"
