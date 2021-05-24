module Command exposing
    ( Command(..)
    , Process(..)
    , ProcessMsg(..)
    , parser
    , view
    , init
    , run
    , complement
    )

import Command.Help as HelpCmd
import Command.Link as LinkCmd
import Command.WhoAmI as WhoAmICmd
import Command.Work as WorkCmd
import Command.List as ListCmd
import Command.ChangeDir as ChangeDirCmd
import Command.MakeDir as MakeDirCmd
import Command.Touch as TouchCmd
import Command.Remove as RemoveCmd
import Command.Concat as ConcatCmd
import FileSystem exposing (FileSystem(..))
import Html exposing (..)
import Lazy.Tree.Zipper exposing (Zipper)
import Parser exposing ((|.), (|=), Parser)
import Dict
import Command.State as State exposing (ProcState)


type Command
    = CmdErr String
    | None
    | Help HelpCmd.Help
    | WhoAmI WhoAmICmd.WhoAmI
    | Work WorkCmd.Work
    | Link LinkCmd.Link
    | List ListCmd.List
    | ChangeDir ChangeDirCmd.ChangeDir
    | MakeDir MakeDirCmd.MakeDir
    | Touch TouchCmd.Touch
    | Remove RemoveCmd.Remove
    | Concat ConcatCmd.Concat

    
type Process
    = Stay
    | LinkProc LinkCmd.Proc


type ProcessMsg
    = Init
    | LinkProcMsg LinkCmd.Msg


parser : Parser Command
parser =
    Parser.oneOf
        [ Parser.succeed None
            |. Parser.end
        , HelpCmd.parser |> Parser.map Help
        , WhoAmICmd.parser |> Parser.map WhoAmI
        , WorkCmd.parser |> Parser.map Work
        , LinkCmd.parser |> Parser.map Link
        , ListCmd.parser |> Parser.map List
        , ChangeDirCmd.parser |> Parser.map ChangeDir
        , MakeDirCmd.parser |> Parser.map MakeDir
        , TouchCmd.parser |> Parser.map Touch
        , RemoveCmd.parser |> Parser.map Remove
        , ConcatCmd.parser |> Parser.map Concat
        ]


init : Command -> Zipper FileSystem -> Process
init cmd dir =
    case cmd of
        Link (LinkCmd.Link args) ->
            LinkCmd.init
                args
                (Dict.fromList
                    [ ( "GitHub", "https://github.com/uzimaru0000" )
                    , ( "Twitter", "https://twitter.com/uzimaru0000" )
                    , ( "Facebook", "https://www.facebook.com/shuji.oba.1" )
                    , ( "zenn", "https://zenn.dev/uzimaru0000" )
                    , ( "Blog", "http://blog.uzimaru.com" )
                    ]
                )
                |> LinkProc
                
        _ -> Stay

        -- Work workCmd ->
        --     ( Ok dir
        --     , WorkCmd.run
        --         workCmd
        --         (Dict.fromList
        --             [ ( "WeatherApp", ("WeatherApp made by Elm.", "https://uzimaru0000.github.io/elm-weather-app") )
        --             , ( "UniTEA", ("Implementation of The Elm Architecture for Unity3D", "https://github.com/uzimaru0000/UniTEA") )
        --             , ( "TabClock", ("Chrome extension to display clock on NewTab", "https://github.com/uzimaru0000/TabClock") )
        --             , ( "VR", ("Summary made with VR.", "https://twitter.com/i/moments/912461981851860992") )
        --             , ( "Splash", ("Applications that simulate ink splash", "https://splash.uzimaru.com/"))
        --             , ( "clumsy", ("Clone of git implemented in rust.", "https://github.com/uzimaru0000/clumsy"))
        --             ]
        --         )
        --     )
        -- 
        -- ChangeDir changeDirCmd ->
        --     (ChangeDirCmd.run changeDirCmd dir, Cmd.none)

        -- MakeDir makeDirCmd ->
        --     (MakeDirCmd.run makeDirCmd dir, Cmd.none)

        -- Touch touchCmd ->
        --     (TouchCmd.run touchCmd dir, Cmd.none)

        -- Remove removeCmd ->
        --     (RemoveCmd.run removeCmd dir, Cmd.none)


run : ProcessMsg -> Process -> (ProcState Process, Cmd ProcessMsg)
run msg proc =
    case (msg, proc) of
        (Init, LinkProc linkProc) ->
            LinkCmd.run LinkCmd.NoOp linkProc
                |> Tuple.mapFirst (State.map LinkProc)
                |> Tuple.mapSecond (Cmd.map LinkProcMsg)

        (LinkProcMsg linkMsg, LinkProc linkProc) ->
            LinkCmd.run linkMsg linkProc
                |> Tuple.mapFirst (State.map LinkProc)
                |> Tuple.mapSecond (Cmd.map LinkProcMsg)
                
        _ ->
            (State.Exit Stay, Cmd.none)


view : Process -> Html msg
view cmd =
    case cmd of
        LinkProc linkProc ->
            LinkCmd.view linkProc
            
        Stay ->
            Html.text ""

        -- Help _ ->
        --     HelpCmd.view
        --         "Welcome to the uzimaru's portfolio site!!"
        --         "[Basic commands]"
        --         [ HelpCmd.info
        --         , WhoAmICmd.info
        --         , WorkCmd.info
        --         , LinkCmd.info
        --         ]

        -- Work workCmd ->
        --     WorkCmd.view
        --         workCmd
        --         (Dict.fromList
        --             [ ( "WeatherApp", ("WeatherApp made by Elm.", "https://uzimaru0000.github.io/elm-weather-app") )
        --             , ( "UniTEA", ("Implementation of The Elm Architecture for Unity3D", "https://github.com/uzimaru0000/UniTEA") )
        --             , ( "TabClock", ("Chrome extension to display clock on NewTab", "https://github.com/uzimaru0000/TabClock") )
        --             , ( "VR", ("Summary made with VR.", "https://twitter.com/i/moments/912461981851860992") )
        --             , ( "Splash", ("Applications that simulate ink splash", "https://splash.uzimaru.com/"))
        --             , ( "clumsy", ("Clone of git implemented in rust.", "https://github.com/uzimaru0000/clumsy"))
        --             ]
        --         )

        -- WhoAmI whoamiCmd ->
        --     WhoAmICmd.view
        --         whoamiCmd
        --         [ ( "Name", "Shuji Oba (uzimaru)" )
        --         , ( "Age", "22" )
        --         , ( "Hobby", "Cooking, Programming" )
        --         , ( "Likes", "WebFrontend, Elm, Rust" )
        --         ]

        -- List listCmd ->
        --     ListCmd.view
        --         listCmd
        --         fileSystem

        -- ChangeDir _ ->
        --     ChangeDirCmd.view

        -- MakeDir makeDirCmd ->
        --     MakeDirCmd.view makeDirCmd

        -- Touch touchCmd ->
        --     TouchCmd.view touchCmd

        -- Remove removeCmd ->
        --     RemoveCmd.view removeCmd
        -- 
        -- Concat concatCmd ->
        --     ConcatCmd.view concatCmd fileSystem

        -- CmdErr err ->
        --     Html.div [] [ Html.text err ]


complementList : List String
complementList =
    [ "help"
    , "work"
    , "whoami"
    , "link"
    , "ls"
    , "cd" 
    , "mkdir"
    , "touch"
    , "rm"
    , "cat"
    ]

complement : String -> List String
complement input =
    if String.isEmpty input then
        []
    else
        complementList
            |> List.filter (String.startsWith input)
