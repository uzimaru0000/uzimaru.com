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
    List String


type alias Commands =
    ( Command, Args )


type CDError
    = NotExist
    | TargetIsFile


remove : Args -> Zipper Directory -> Result String (Zipper Directory)
remove args dir =
    let
        newDir =
            case args of
                maybeOpt :: path :: _ ->
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
                    dir
                        |> Zipper.openPath (\p d -> p == Dir.getName d) (String.split "/" path)
                        |> Result.mapError (always "rm: No such file or directory")
                        |> Result.andThen
                            (\d ->
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
changeDir args dir =
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
    in
    div [ Attr.class "help" ]
        [ info
            |> List.map
                (\( cmd, b ) ->
                    li []
                        [ a [ Ev.onClick ( cmd, [] ) ] [ text <| commandToString cmd ]
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
        [ figure [] [ img [ Attr.src "https://pbs.twimg.com/profile_images/1208808311790813184/LuBDQbAI_400x400.jpg" ] [] ]
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
