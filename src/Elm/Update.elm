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
                    case executeCommand cmds model of
                        Ok m ->
                            display cmds m

                        Err errMsg ->
                            display
                                (cmds
                                    |> Tuple.mapFirst Cmd.commandToString
                                    |> Tuple.mapFirst (\x -> Error x errMsg)
                                )
                                model
            in
            ( { newModel
                | input = ""
                , history = model.history ++ [ cmds ]
              }
            , [ tarminalJumpToBotton "tarminal"
              , newModel.directory
                    |> Zipper.getTree
                    |> Dir.dismantlers
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

        GetWindow (Ok { element, viewport }) ->
            let
                x =
                    (viewport.width - element.width) / 2

                y =
                    (viewport.height - element.height) / 2
            in
            ( { model | windowPos = ( x, y ) }
            , Cmd.none
            )

        ClickHeader isClick ->
            ( { model
                | isClickHeader = isClick
              }
            , Cmd.none
            )

        MoveMouse ( moveX, moveY ) ->
            let
                x =
                    Tuple.first model.windowPos

                y =
                    Tuple.second model.windowPos
            in
            ( { model
                | windowPos = ( x + moveX, y + moveY )
              }
            , Cmd.none
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
                            Error raw <| "Shell: Unknown command " ++ raw
            in
            ( cmd, args )

        [] ->
            ( Error "" "", [] )


executeCommand : Commands -> Model -> Result String Model
executeCommand ( cmd, args ) model =
    case ( cmd, args ) of
        ( MakeDir, name :: _ ) ->
            Ok
                { model
                    | directory =
                        model.directory
                            |> Zipper.insert (Tree.singleton <| Directory { name = name } [])
                }

        ( Touch, name :: _ ) ->
            Ok
                { model
                    | directory =
                        model.directory
                            |> Zipper.insert (Tree.singleton <| File { name = name })
                }

        ( ChangeDir, path :: _ ) ->
            let
                newDir =
                    model.directory
                        |> Zipper.openPath dirCheck (String.split "/" path)
            in
            case newDir of
                Ok dir ->
                    Ok { model | directory = dir }

                Err _ ->
                    [ Cmd.commandToString ChangeDir ++ ":"
                    , "The directory"
                    , "'" ++ path ++ "'"
                    , "does not exist"
                    ]
                        |> String.join " "
                        |> Err

        ( ChangeDir, [] ) ->
            Ok
                { model
                    | directory =
                        model.directory
                            |> Zipper.root
                }

        ( Remove, _ ) ->
            case remove args model.directory of
                Ok dir ->
                    Ok
                        { model
                            | directory =
                                dir
                                    |> Zipper.attempt Zipper.delete
                        }

                Err msg ->
                    Err msg

        _ ->
            Ok model


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


dirCheck : String -> Directory -> Bool
dirCheck path dir =
    case dir of
        Directory { name } _ ->
            name == path

        File _ ->
            False


remove : Cmd.Args -> Zipper Directory -> Result String (Zipper Directory)
remove args dir =
    case args of
        maybeOpt :: path :: tail ->
            case String.uncons maybeOpt of
                Just ( '-', "r" ) ->
                    dir
                        |> Zipper.openPath (\p d -> p == Dir.getName d) (String.split "/" path)
                        |> Result.mapError (always "rm: No such file or directory")

                Just ( '-', opt ) ->
                    Err <| "rm: illegal opiton -- " ++ opt

                _ ->
                    Err <| "rm: invalid argument -- " ++ String.join " " args

        path :: _ ->
            Zipper.openPath (\p d -> p == Dir.getName d) (String.split "/" path) dir
                |> Result.mapError (always "rm: No such file or directory")
                |> Result.andThen
                    (\d ->
                        case Zipper.current d of
                            Directory _ _ ->
                                Err <| "rm: " ++ path ++ ": is a directory"

                            File _ ->
                                Ok dir
                    )

        [] ->
            Err <| "usage: rm [-r] file"


tarminalJumpToBotton : String -> Cmd Msg
tarminalJumpToBotton id =
    Browser.Dom.getViewportOf id
        |> Task.andThen (\info -> Browser.Dom.setViewportOf id 0 info.scene.height)
        |> Task.attempt (\_ -> NoOp)
