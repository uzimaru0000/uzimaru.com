module Update exposing (update)

import Browser.Dom
import Model exposing (..)
import Task
import Lazy.Tree.Zipper as Zipper
import Lazy.Tree as Tree
import Directory as Dir exposing (Directory(..))


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
            let
                cmds =
                    parseCommand model.input

                newModel =
                    executeCommand model cmds
            in
                ( { newModel
                    | input = ""
                    , history = model.history ++ [ cmds ]
                  }
                , tarminalJumpToBotton "tarminal"
                )

        OnCommand cmds ->
            ( { model
                | history = model.history ++ [ cmds ]
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

        Focus ->
            ( model
            , Task.attempt (\_ -> NoOp) <| Browser.Dom.focus "prompt"
            )

        _ ->
            ( model, Cmd.none )


parseCommand : String -> Commands
parseCommand str =
    case String.split " " str |> List.filter (not << String.isEmpty) of
        raw :: args ->
            let
                cmd =
                    case raw of
                        "whoami" ->
                            WhoAmI

                        "work" ->
                            Work

                        "link" ->
                            Link

                        "help" ->
                            Help

                        "ls" ->
                            List

                        "mkdir" ->
                            MakeDir

                        "touch" ->
                            Touch

                        "cd" ->
                            ChangeDir

                        _ ->
                            None str
            in
                ( cmd, args )

        [] ->
            ( None str, [] )


executeCommand : Model -> Commands -> Model
executeCommand model ( cmd, args ) =
    case ( cmd, args ) of
        ( MakeDir, name :: _ ) ->
            { model
                | directory =
                    model.directory
                        |> Zipper.insert (Tree.singleton <| Directory { name = name } [])
            }

        ( Touch, name :: _ ) ->
            { model
                | directory =
                    model.directory
                        |> Zipper.insert (Tree.singleton <| File { name = name })
            }

        _ ->
            model


tarminalJumpToBotton : String -> Cmd Msg
tarminalJumpToBotton id =
    Browser.Dom.getViewportOf id
        |> Task.andThen (\info -> Browser.Dom.setViewportOf id 0 info.scene.height)
        |> Task.attempt (\_ -> NoOp)
