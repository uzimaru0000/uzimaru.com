module Update exposing (update)

import Browser.Dom
import Command as Cmd exposing (Command(..))
import Directory as Dir exposing (Directory(..))
import Html
import Lazy.Tree as Tree
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
            let
                newModel =
                    case executeCommand cmd model of
                        Ok m ->
                            display cmd m

                        Err errMsg ->
                            display
                                (cmd
                                    |> Cmd.commandToString
                                    |> (\x -> Error x errMsg)
                                )
                                model
            in
            ( { newModel
                | input = ""
                , history = model.history ++ [ cmd ]
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


parseCommand : String -> Command
parseCommand str =
    case Parser.run Cmd.parser str of
        Ok cmd ->
            cmd

        Err _ ->
            Cmd.Error "" ""


executeCommand : Command -> Model -> Result String Model
executeCommand cmd model =
    case cmd of
        _ ->
            Ok model


display : Command -> Model -> Model
display cmd model =
    { model
        | view =
            model.view
                ++ [ Html.div []
                        [ Html.span []
                            [ Dir.prompt model.directory
                            , Cmd.commandToString cmd
                                |> Html.text
                            ]
                        , Cmd.outputView cmd |> Html.map OnCommand
                        ]
                   ]
    }


tarminalJumpToBotton : String -> Cmd Msg
tarminalJumpToBotton id =
    Browser.Dom.getViewportOf id
        |> Task.andThen (\info -> Browser.Dom.setViewportOf id 0 info.scene.height)
        |> Task.attempt (\_ -> NoOp)
