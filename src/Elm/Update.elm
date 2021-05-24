module Update exposing (update)

import Browser.Dom
import Command as Cmd exposing (Command(..))
import FileSystem exposing (FileSystem(..))
import Model exposing (..)
import Parser
import Task
import Command.State exposing (ProcState(..))



-- update


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        OnInput str ->
            ( { model
                | input = str
                , complement = Nothing
              }
            , Cmd.none
            )

        OnEnter ->
            let
                (state, procEffect) =
                    parseCommand model.input
                        |> \c -> Cmd.init c model.fileSystem
                        
                (newModel, effect)
                    = update (RunProcess state) model
            in
            (newModel, [Cmd.map ProcessMsg procEffect, effect] |> Cmd.batch)

        OnTab ->
            let
                complements =
                    case model.complement of
                        Just comp -> comp
                        Nothing -> Cmd.complement model.input
                
                complementHead =
                    List.head complements
                        |> Maybe.withDefault model.input

                complementTail =
                    List.tail complements
                        |> Maybe.withDefault []
            in
            ( { model
                | complement = Just complementTail
                , input = complementHead
              }
            , Cmd.none
            )

        RunProcess state ->
            let
                newModel =
                    case state of
                        Running p ->
                            { model
                               | process = p
                            }

                        Exit p ->
                            { model
                               | fileSystem = Cmd.getFS p |> Maybe.withDefault model.fileSystem
                               , history = model.history ++ [ History model.fileSystem model.input state ]
                               , process = Cmd.Stay
                               , input = ""
                            }
                        
                        Error _ _ ->
                            { model
                               | history = model.history ++ [ History model.fileSystem model.input state ]
                               , process = Cmd.Stay
                               , input = ""
                            }
            in
            ( newModel
            , [ tarminalJumpToBotton "tarminal"
              , focus
              ] |> Cmd.batch
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
                , complement = Nothing
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
