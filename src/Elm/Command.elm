module Command exposing
    ( Command(..)
    , Error(..)
    , dirItem
    , list
    , parser
    , view
    , run
    )

import Command.Help as HelpCmd
import Command.Link as LinkCmd
import Command.WhoAmI as WhoAmICmd
import Command.Work as WorkCmd
import Directory as Dir exposing (Directory(..))
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Ev
import Lazy.Tree.Zipper as Zipper exposing (Zipper)
import Parser exposing ((|.), (|=), Parser)
import Set
import Dict


type CommandTag
    = Help_
    | WhoAmI_
    | Work_
    | Link_


type Command
    = CmdErr Error 
    | None
    | Help HelpCmd.Help
    | WhoAmI WhoAmICmd.WhoAmI
    | Work WorkCmd.Work
    | Link LinkCmd.Link



-- | List
-- | MakeDir
-- | Touch
-- | ChangeDir
-- | Remove


type Error
    = NotExist
    | TargetIsFile
    | UnknownCommand String


parser : Parser Command
parser =
    Parser.oneOf
        [ Parser.succeed None
            |. Parser.end
        , HelpCmd.parser |> Parser.map Help
        , WhoAmICmd.parser |> Parser.map WhoAmI
        , WorkCmd.parser |> Parser.map Work
        , LinkCmd.parser |> Parser.map Link
        ]


strToCmd : String -> Maybe CommandTag
strToCmd str =
    case str of
        "help" ->
            Just Help_

        "whoami" ->
            Just WhoAmI_

        "link" ->
            Just Link_

        "work" ->
            Just Work_

        _ ->
            Nothing


cmdToStr : CommandTag -> String
cmdToStr cmd =
    case cmd of
        Help_ -> "help"
        WhoAmI_ -> "whoami"
        Link_ -> "link"
        Work_ -> "work"


-- remove : Args -> Zipper Directory -> Result String (Zipper Directory)
-- remove args dir =
--     let
--         newDir =
--             case args of
--                 maybeOpt :: path :: _ ->
--                     case String.uncons maybeOpt of
--                         Just ( '-', "r" ) ->
--                             dir
--                                 |> Zipper.openPath (\p d -> p == Dir.getName d) (String.split "/" path)
--                                 |> Result.mapError (always "rm: No such file or directory")
--                         Just ( '-', opt ) ->
--                             Err <| "rm: illegal opiton -- " ++ opt
--                         _ ->
--                             Err <| "rm: invalid argument -- " ++ String.join " " args
--                 path :: _ ->
--                     dir
--                         |> Zipper.openPath (\p d -> p == Dir.getName d) (String.split "/" path)
--                         |> Result.mapError (always "rm: No such file or directory")
--                         |> Result.andThen
--                             (\d ->
--                                 case Zipper.current d of
--                                     Directory _ _ ->
--                                         Err <| "rm: " ++ path ++ ": is a directory"
--                                     File _ ->
--                                         Ok d
--                             )
--                 [] ->
--                     Err "usage: rm [-r] file"
--     in
--     newDir
--         |> Result.map (Zipper.attempt Zipper.delete)
-- changeDir : Args -> Zipper Directory -> Result String (Zipper Directory)
-- changeDir args dir =
--     case args of
--         path :: _ ->
--             changeDirHelper (String.split "/" path) dir
--                 |> Result.mapError
--                     (\x ->
--                         case x of
--                             NotExist ->
--                                 "cd: The directory '" ++ path ++ "' does not exist"
--                             TargetIsFile ->
--                                 "cd: '" ++ path ++ "' is not a directory"
--                     )
--         [] ->
--             Ok <| Zipper.root dir


-- changeDirHelper : List String -> Zipper Directory -> Result CDError (Zipper Directory)
-- changeDirHelper path dir =
--     case path of
--         ".." :: tail ->
--             dir
--                 |> Zipper.up
--                 |> Result.fromMaybe NotExist
--                 |> Result.andThen (changeDirHelper tail)

--         "." :: tail ->
--             changeDirHelper tail dir

--         head :: tail ->
--             dir
--                 |> Zipper.open
--                     (\x ->
--                         case x of
--                             Directory { name } _ ->
--                                 name == head

--                             File _ ->
--                                 False
--                     )
--                 |> Result.fromMaybe
--                     (case Zipper.open (Dir.getName >> (==) head) dir |> Maybe.map Zipper.current of
--                         Just (File _) ->
--                             TargetIsFile

--                         Nothing ->
--                             NotExist

--                         _ ->
--                             NotExist
--                     )
--                 |> Result.andThen (changeDirHelper tail)

--         [] ->
--             Ok dir


run : Command -> Cmd msg
run cmd =
    case cmd of
        Link linkCmd ->
            LinkCmd.run
                linkCmd
                (Dict.fromList
                    [ ( "GitHub", "https://github.com/uzimaru0000" )
                    , ( "Twitter", "https://twitter.com/uzimaru0000" )
                    , ( "Facebook", "https://www.facebook.com/shuji.oba.1" )
                    , ( "zenn", "https://zenn.dev/uzimaru0000" )
                    , ( "Blog", "http://blog.uzimaru.com" )
                    ]
                )

        Work workCmd ->
            WorkCmd.run
                workCmd
                (Dict.fromList
                    [ ( "WeatherApp", ("WeatherApp made by Elm.", "https://uzimaru0000.github.io/elm-weather-app") )
                    , ( "UniTEA", ("Implementation of The Elm Architecture for Unity3D", "https://github.com/uzimaru0000/UniTEA") )
                    , ( "TabClock", ("Chrome extension to display clock on NewTab", "https://github.com/uzimaru0000/TabClock") )
                    , ( "VR", ("Summary made with VR.", "https://twitter.com/i/moments/912461981851860992") )
                    ]
                )

        _ ->
            Cmd.none


view : Command -> Html Command
view cmd =
    case cmd of
        Help helpCmd ->
            HelpCmd.view
                "Welcome to the uzimaru's portfolio site!!"
                "[Basic commands]"
                [ HelpCmd.info
                , WhoAmICmd.info
                , WorkCmd.info
                , LinkCmd.info
                ]

        Work workCmd ->
            WorkCmd.view
                workCmd
                (Dict.fromList
                    [ ( "WeatherApp", ("WeatherApp made by Elm.", "https://uzimaru0000.github.io/elm-weather-app") )
                    , ( "UniTEA", ("Implementation of The Elm Architecture for Unity3D", "https://github.com/uzimaru0000/UniTEA") )
                    , ( "TabClock", ("Chrome extension to display clock on NewTab", "https://github.com/uzimaru0000/TabClock") )
                    , ( "VR", ("Summary made with VR.", "https://twitter.com/i/moments/912461981851860992") )
                    ]
                )

        WhoAmI whoamiCmd ->
            WhoAmICmd.view
                whoamiCmd
                [ ( "Name", "Shuji Oba (uzimaru)" )
                , ( "Age", "21" )
                , ( "Hobby", "Cooking, Programming" )
                , ( "Likes", "Unity, Elm, Golang" )
                ]

        Link linkCmd ->
            LinkCmd.view 
                linkCmd
                (Dict.fromList
                    [ ( "GitHub", "https://github.com/uzimaru0000" )
                    , ( "Twitter", "https://twitter.com/uzimaru0000" )
                    , ( "Facebook", "https://www.facebook.com/shuji.oba.1" )
                    , ( "zenn", "https://zenn.dev/uzimaru0000" )
                    , ( "Blog", "http://blog.uzimaru.com" )
                    ]
                )

        CmdErr err ->
            Html.div []
                [ case err of
                    UnknownCommand str ->
                        [ "Unknown command:", str ] 
                            |> String.join " "
                            |> Html.text
                    
                    _ ->
                        Html.text "error"
                ]

        None ->
            Html.text ""


list : Zipper Directory -> Html Command
list dir =
    div [ Attr.class "ls" ]
        [ dir
            |> Zipper.children
            |> List.map dirItem
            |> ul []
        ]


dirItem : Directory -> Html Command
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
