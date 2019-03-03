module Update exposing (update)

import Browser.Dom
import Command as Cmd exposing (Command(..), Commands)
import Directory as Dir exposing (Directory(..))
import Html
import Lazy.Tree as Tree
import Lazy.Tree.Zipper as Zipper exposing (Zipper)
import LocalStorage as LS
import Model exposing (..)
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

        OnCommand cmds ->
            let
                newModel =
                    model
                        |> display cmds
                        |> executeCommand cmds
            in
                ( { newModel
                    | input = ""
                    , history = model.history ++ [ cmds ]
                  }
                , [ tarminalJumpToBotton "tarminal"
                  , newModel.directory
                        |> Debug.log ""
                        |> Zipper.current
                        |> Dir.encoder
                        |> LS.store
                  ]
                    |> Cmd.batch
                )

        Clear ->
            ( { model | history = [], input = "", view = [] }
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

                        "rm" ->
                            Remove

                        _ ->
                            None str
            in
                ( cmd, args )

        [] ->
            ( None str, [] )


executeCommand : Commands -> Model -> Model
executeCommand ( cmd, args ) model =
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

        ( ChangeDir, path :: _ ) ->
            { model
                | directory =
                    model.directory
                        |> Zipper.attempt (Just >> (path |> String.split "/" |> changeDir))
            }

        ( ChangeDir, [] ) ->
            { model
                | directory =
                    model.directory
                        |> Zipper.root
            }

        ( Remove, path :: _ ) ->
            { model
                | directory =
                    model.directory
                        |> Zipper.attempt (Zipper.open <| Dir.getName >> (==) path)
                        |> Zipper.attempt Zipper.delete
            }

        _ ->
            model


display : Commands -> Model -> Model
display ( cmd, args ) model =
    { model
        | view =
            model.view
                ++ [ Html.div []
                        [ Html.span []
                            [ Dir.prompt model.directory
                            , (Cmd.commandToString cmd :: args)
                                |> String.join " "
                                |> Html.text
                            ]
                        , Cmd.outputView model.directory cmd |> Html.map OnCommand
                        ]
                   ]
    }


changeDir : List String -> Maybe (Zipper Directory) -> Maybe (Zipper Directory)
changeDir pathList maybeDir =
    case maybeDir of
        Just dir ->
            case pathList of
                ".." :: tail ->
                    dir
                        |> Zipper.up
                        |> changeDir tail

                head :: tail ->
                    let
                        moved =
                            dir
                                |> Zipper.open (Dir.getName >> (==) head)
                    in
                        case Maybe.map Zipper.current moved of
                            Just (Directory _ _) ->
                                changeDir tail moved

                            _ ->
                                Nothing

                [] ->
                    maybeDir

        Nothing ->
            Nothing


tarminalJumpToBotton : String -> Cmd Msg
tarminalJumpToBotton id =
    Browser.Dom.getViewportOf id
        |> Task.andThen (\info -> Browser.Dom.setViewportOf id 0 info.scene.height)
        |> Task.attempt (\_ -> NoOp)
