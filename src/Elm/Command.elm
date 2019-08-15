module Command exposing
    ( Args
    , Command(..)
    , Commands
    , changeDir
    , commandToString
    , createList
    , dirItem
    , help
    , links
    , list
    , outputView
    , parseArgs
    , parseCommand
    , parseCommands
    , remove
    , whoami
    , work
    )

import Directory as Dir exposing (Directory(..))
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Ev
import Lazy.Tree.Zipper as Zipper exposing (Zipper)


type Command
    = Error String String
    | Help
    | WhoAmI
    | Work
    | Link
    | List
    | MakeDir
    | Touch
    | ChangeDir
    | Remove


type alias Args =
    { opts : List String
    , args : List String
    , raw : String
    }


type alias Commands =
    ( Command, Args )


type CDError
    = NotExist
    | TargetIsFile


parseCommands : String -> Commands
parseCommands str =
    case String.split " " str |> List.filter (not << String.isEmpty) of
        rawCmd :: args ->
            let
                parsedArgs =
                    parseArgs args
            in
            ( parseCommand rawCmd, { parsedArgs | raw = str } )

        [] ->
            ( Error "" "", { opts = [], args = [], raw = str } )


parseCommand : String -> Command
parseCommand raw =
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


parseArgs : List String -> Args
parseArgs rawArgs =
    rawArgs
        |> List.foldl
            (\x { args, opts, raw } ->
                case String.uncons x of
                    Just ( '-', opt ) ->
                        { args = args, opts = opt :: opts, raw = raw }

                    Just ( _, opt ) ->
                        { args = x :: args, opts = opts, raw = raw }

                    Nothing ->
                        { args = args, opts = opts, raw = raw }
            )
            { args = [], opts = [], raw = "" }


remove : Args -> Zipper Directory -> Result String (Zipper Directory)
remove { opts, args } dir =
    let
        flags =
            opts
                |> List.foldl
                    (\x acc ->
                        case x of
                            "r" ->
                                { acc | isRecursive = True }

                            _ ->
                                { acc | error = Just <| "rm: illegal opiton -- " ++ x }
                    )
                    { isRecursive = False, error = Nothing }

        newDir =
            case args of
                path :: _ ->
                    dir
                        |> Zipper.openPath (\p d -> p == Dir.getName d) (String.split "/" path)
                        |> Result.mapError (\_ -> flags.error |> Maybe.withDefault "rm: No such file or directory")
                        |> Result.andThen
                            (\d ->
                                if flags.isRecursive then
                                    Ok d

                                else
                                    case Zipper.current d of
                                        Directory _ _ ->
                                            Err <| "rm: " ++ path ++ ": is a directory"

                                        File _ ->
                                            Ok d
                            )

                [] ->
                    Err "usage: rm [-r] file"
    in
    newDir
        |> Result.map (Zipper.attempt Zipper.delete)


changeDir : Args -> Zipper Directory -> Result String (Zipper Directory)
changeDir { opts, args } dir =
    case args of
        path :: _ ->
            changeDirHelper (String.split "/" path) dir
                |> Result.mapError
                    (\x ->
                        case x of
                            NotExist ->
                                "cd: The directory '" ++ path ++ "' does not exist"

                            TargetIsFile ->
                                "cd: '" ++ path ++ "' is not a directory"
                    )

        [] ->
            Ok <| Zipper.root dir


changeDirHelper : List String -> Zipper Directory -> Result CDError (Zipper Directory)
changeDirHelper path dir =
    case path of
        ".." :: tail ->
            dir
                |> Zipper.up
                |> Result.fromMaybe NotExist
                |> Result.andThen (changeDirHelper tail)

        "." :: tail ->
            changeDirHelper tail dir

        head :: tail ->
            dir
                |> Zipper.open
                    (\x ->
                        case x of
                            Directory { name } _ ->
                                name == head

                            File _ ->
                                False
                    )
                |> Result.fromMaybe
                    (case Zipper.open (Dir.getName >> (==) head) dir |> Maybe.map Zipper.current of
                        Just (File _) ->
                            TargetIsFile

                        Nothing ->
                            NotExist

                        _ ->
                            NotExist
                    )
                |> Result.andThen (changeDirHelper tail)

        [] ->
            Ok dir


commandToString : Command -> String
commandToString cmd =
    case cmd of
        Error c _ ->
            c

        Help ->
            "help"

        WhoAmI ->
            "whoami"

        Work ->
            "work"

        Link ->
            "link"

        List ->
            "ls"

        MakeDir ->
            "mkdir"

        Touch ->
            "touch"

        ChangeDir ->
            "cd"

        Remove ->
            "rm"


outputView : Zipper Directory -> Command -> Html Commands
outputView dir cmd =
    case cmd of
        Error _ msg ->
            div
                [ if String.isEmpty msg then
                    Attr.class ""

                  else
                    Attr.style "margin" "16px 0"
                ]
                [ text msg
                ]

        Help ->
            help

        WhoAmI ->
            whoami

        Work ->
            work

        Link ->
            links

        List ->
            list dir

        _ ->
            text ""


createList : ( String, String ) -> Html msg
createList ( a, b ) =
    li []
        [ span [] [ text a ]
        , span [] [ text b ]
        ]


help : Html Commands
help =
    let
        info =
            List.map2 Tuple.pair
                [ Help, WhoAmI, Work, Link ]
                [ "Help about this site."
                , "Who is me?"
                , "List works which were made by me."
                , "List links which to me."
                ]

        args cmd =
            { opts = []
            , args = []
            , raw = commandToString cmd
            }
    in
    div [ Attr.class "help" ]
        [ info
            |> List.map
                (\( cmd, b ) ->
                    li []
                        [ a [ Ev.onClick ( cmd, args cmd ) ] [ text <| commandToString cmd ]
                        , span [] [ text b ]
                        ]
                )
            |> ul [ Attr.class "list" ]
        ]


whoami : Html Commands
whoami =
    let
        info =
            [ ( "Name", "Shuji Oba (uzimaru)" )
            , ( "Age", "21" )
            , ( "Hobby", "Cooking, Programming" )
            , ( "Likes", "Unity, Elm, Golang" )
            ]
    in
    div [ Attr.class "whoami" ]
        [ figure [] [ img [ Attr.src "icon2.png" ] [] ]
        , info
            |> List.map createList
            |> ul [ Attr.class "list" ]
        ]


work : Html Commands
work =
    let
        info =
            [ ( "WeatherApp", "WeatherApp made by Elm.", "https://uzimaru0000.github.io/elm-weather-app" )
            , ( "Sticky", "Sticky note app that can use markdown.", "https://github.com/uzimaru0000/Sticky" )
            , ( "Stock", "Notebook app that can use Markdown.", "https://uzimaru0000.github.io/stock" )
            , ( "VR", "Summary made with VR.", "https://twitter.com/i/moments/912461981851860992" )
            ]
    in
    div [ Attr.class "work" ]
        [ info
            |> List.map
                (\( title, subTitle, url ) ->
                    li []
                        [ a [ Attr.href url, Attr.target "_blink" ] [ text title ]
                        , span [] [ text subTitle ]
                        ]
                )
            |> ul [ Attr.class "list" ]
        ]


links : Html Commands
links =
    let
        info =
            [ ( "GitHub", "https://github.com/uzimaru0000" )
            , ( "Twitter", "https://twitter.com/uzimaru0000" )
            , ( "Facebook", "https://www.facebook.com/shuji.oba.1" )
            , ( "Qiita", "https://qiita.com/uzimaru0000" )
            , ( "Blog", "http://uzimaru0601.hatenablog.com" )
            ]
    in
    div [ Attr.class "links" ]
        [ info
            |> List.map
                (\( title, url ) ->
                    li []
                        [ a [ Attr.href url, Attr.target "_blink" ] [ text title ]
                        ]
                )
            |> ul [ Attr.class "list" ]
        ]


list : Zipper Directory -> Html Commands
list dir =
    div [ Attr.class "ls" ]
        [ dir
            |> Zipper.children
            |> List.map dirItem
            |> ul []
        ]


dirItem : Directory -> Html Commands
dirItem dir =
    case dir of
        Directory { name } _ ->
            li
                [ Attr.class "directory" ]
                [ text <| name ++ "/" ]

        File { name } ->
            li
                [ Attr.class "file" ]
                [ text name ]
