module Command.Ulmus exposing (..)

import Browser.Dom
import Command.ChangeDir exposing (argsParser)
import Command.Help exposing (HelpInfo(..))
import Command.State exposing (ProcState)
import CustomElement exposing (terminalInput)
import Dict
import FileSystem exposing (File, FileSystem)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Ev
import Json.Decode as JD
import Lazy.Tree.Zipper exposing (Zipper)
import Parser exposing ((|.), (|=), Parser)
import Svg.Attributes exposing (result)
import Task
import Ulmus exposing (Ctx)
import Ulmus.AST as Ulmus
import Ulmus.Parser as Ulmus
import Utils


type Ulmus
    = Ulmus Args


type alias Args =
    { filePath : Maybe String
    }


type alias Flags =
    { fs : Zipper FileSystem
    }


type alias Proc =
    { ctx : Ctx
    , input : String
    , history : List ( String, String )
    , buffer : List String
    }


type Msg
    = NoOp
    | Input String
    | Focus
    | OnEnter
    | Clear


parser : Parser Ulmus
parser =
    Parser.succeed Ulmus
        |. Parser.keyword "ulmus"
        |. Parser.spaces
        |= argsParser { filePath = Nothing }


argsParser : Args -> Parser Args
argsParser =
    Utils.argsParser <|
        \default ->
            Parser.oneOf
                [ Parser.succeed (\str -> { default | filePath = Just str })
                    |= Utils.anyString
                ]


info : HelpInfo
info =
    HelpInfo
        { name = "ulmus", info = "", detailInfo = [] }


init : Args -> Flags -> ( ProcState Proc, Cmd Msg )
init args flags =
    case args.filePath of
        Just path ->
            let
                path_ =
                    String.split "/" path

                result =
                    FileSystem.readFile path_ flags.fs
                        |> Result.mapError FileSystem.errorToString
                        |> Result.andThen (.data >> Utils.bytesToString >> Result.fromMaybe "error")
                        |> Result.andThen (Parser.run Ulmus.parser >> Result.mapError Parser.deadEndsToString)
                        |> Result.andThen (Ulmus.evalAll (Dict.fromList []))
            in
            case result of
                Ok ( res, ctx ) ->
                    ( Command.State.Exit
                        { ctx = ctx
                        , input = ""
                        , history = [ ( "", Ulmus.show res ) ]
                        , buffer = []
                        }
                    , Cmd.none
                    )

                Err err ->
                    ( Command.State.Exit
                        { ctx = Dict.fromList []
                        , input = ""
                        , history = [ ( "", err ) ]
                        , buffer = []
                        }
                    , Cmd.none
                    )

        Nothing ->
            ( Command.State.Running
                { ctx = Dict.fromList []
                , input = ""
                , history = []
                , buffer = []
                }
            , focus
            )


run : Msg -> Proc -> ( ProcState Proc, Cmd Msg )
run msg proc =
    case msg of
        Input str ->
            ( Command.State.Running
                { proc
                    | input = str
                }
            , Cmd.none
            )

        Focus ->
            ( Command.State.Running proc
            , focus
            )

        OnEnter ->
            let
                code =
                    String.join "\n" proc.buffer ++ proc.input

                result =
                    Parser.run Ulmus.parser code
                        |> Result.mapError Parser.deadEndsToString
                        |> Result.andThen (Ulmus.evalAll proc.ctx)
            in
            case result of
                Ok ( res, ctx ) ->
                    ( Command.State.Running
                        { proc
                            | ctx = ctx
                            , input = ""
                            , history = proc.history ++ [ ( code, Ulmus.show res ) ]
                            , buffer = []
                        }
                    , Cmd.none
                    )

                Err err ->
                    ( Command.State.Running
                        { proc
                            | input = ""
                            , buffer = proc.buffer ++ [ proc.input ]
                        }
                    , Cmd.none
                    )

        Clear ->
            ( Command.State.Running
                { proc
                    | history = []
                }
            , Cmd.none
            )

        _ ->
            ( Command.State.Running proc, Cmd.none )


view : Proc -> Html Msg
view proc =
    Html.div
        []
        [ Html.div [] <|
            List.map history proc.history
        , proc.buffer
            |> List.map Html.text
            |> List.map (List.singleton >> Html.div [])
            |> Html.div [ Attr.class "whitespace-pre pl-4" ]
        , Html.div []
            [ Html.span [] [ Html.text ">" ]
            , terminalInput
                [ Ev.onInput Input
                , Ev.onClick Focus
                , Attr.value proc.input
                , Attr.id "ulmus_input"
                , onKeyDownWithCtrl
                    (\ctrl code ->
                        case ( ctrl, code ) of
                            ( True, 76 ) ->
                                JD.succeed Clear

                            ( _, 13 ) ->
                                JD.succeed OnEnter

                            _ ->
                                JD.fail "not matching"
                    )
                ]
                []
            ]
        ]


history : ( String, String ) -> Html Msg
history ( input, result ) =
    Html.div
        []
        [ Html.div [ Attr.class "whitespace-pre" ] [ Html.text input ]
        , Html.div []
            [ Html.span [] [ Html.text "-->" ]
            , Html.span [] [ Html.text result ]
            ]
        ]


subscriptions : Proc -> Sub Msg
subscriptions _ =
    Sub.none


focus : Cmd Msg
focus =
    Browser.Dom.focus "ulmus_input"
        |> Task.attempt (\_ -> NoOp)


onKeyDownWithCtrl : (Bool -> Int -> JD.Decoder msg) -> Html.Attribute msg
onKeyDownWithCtrl decoder =
    JD.map2 decoder
        (JD.field "ctrlKey" JD.bool)
        (JD.field "keyCode" JD.int)
        |> JD.andThen identity
        |> JD.map (\x -> ( x, True ))
        |> Ev.preventDefaultOn "keydown"
