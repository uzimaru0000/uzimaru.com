module Command exposing
    ( Command(..)
    , Process(..)
    , ProcessMsg(..)
    , parser
    , view
    , init
    , run
    , complement
    , getFS
    , subscriptions
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
import Command.Sleep as SleepCmd
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
    | Sleep SleepCmd.Sleep

    
type Process
    = Stay
    | HelpProc HelpCmd.Proc
    | LinkProc LinkCmd.Proc
    | WhoAmIProc WhoAmICmd.Proc
    | WorkProc WorkCmd.Proc
    | ListProc ListCmd.Proc
    | TouchProc TouchCmd.Proc
    | ChangeDirProc ChangeDirCmd.Proc
    | MakeDirProc MakeDirCmd.Proc
    | RemoveProc RemoveCmd.Proc
    | ConcatProc ConcatCmd.Proc
    | SleepProc SleepCmd.Proc


type ProcessMsg
    = HelpProcMsg HelpCmd.Msg
    | LinkProcMsg LinkCmd.Msg
    | WhoAmIProcMsg WhoAmICmd.Msg
    | WorkProcMsg WorkCmd.Msg
    | ListProcMsg ListCmd.Msg
    | TouchProcMsg TouchCmd.Msg
    | ChangeDirProcMsg Never
    | MakeDirProcMsg Never
    | RemoveProcMsg Never
    | ConcatProcMsg Never
    | SleepProcMsg SleepCmd.Msg


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
        , SleepCmd.parser |> Parser.map Sleep
        ]


init : Command -> Zipper FileSystem -> (ProcState Process, Cmd ProcessMsg)
init cmd dir =
    case cmd of
        Help _ ->
            HelpCmd.init
                ()
                { message = "Welcome to the uzimaru's portfolio site!!" 
                , label = "[Basic commands]"
                , infos =
                    [ HelpCmd.info
                    , WhoAmICmd.info
                    , WorkCmd.info
                    , LinkCmd.info
                    ]
                }
                |> map HelpProc HelpProcMsg

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
                |> map LinkProc LinkProcMsg
                
        WhoAmI (WhoAmICmd.WhoAmI args) ->
            WhoAmICmd.init
                args
                { infos =
                    [ ( "Name", "Shuji Oba (uzimaru)" )
                    , ( "Age", "22" )
                    , ( "Hobby", "Cooking, Programming" )
                    , ( "Likes", "WebFrontend, Elm, Rust" )
                    ]
                }
                |> map WhoAmIProc WhoAmIProcMsg
                
        Work (WorkCmd.Work args) ->
            WorkCmd.init
                args
                { works =
                    Dict.fromList
                        [ ( "WeatherApp", ("WeatherApp made by Elm.", "https://uzimaru0000.github.io/elm-weather-app") )
                        , ( "UniTEA", ("Implementation of The Elm Architecture for Unity3D", "https://github.com/uzimaru0000/UniTEA") )
                        , ( "TabClock", ("Chrome extension to display clock on NewTab", "https://github.com/uzimaru0000/TabClock") )
                        , ( "VR", ("Summary made with VR.", "https://twitter.com/i/moments/912461981851860992") )
                        , ( "Splash", ("Applications that simulate ink splash", "https://splash.uzimaru.com/"))
                        , ( "clumsy", ("Clone of git implemented in rust.", "https://github.com/uzimaru0000/clumsy"))
                        ] 
                }
                |> map WorkProc WorkProcMsg
                
        List (ListCmd.List args) ->
            ListCmd.init
                args
                { fs = dir
                }
                |> map ListProc ListProcMsg
                
        
        Touch (TouchCmd.Touch args) ->
            TouchCmd.init
                args
                { fs = dir
                }
                |> map TouchProc TouchProcMsg
                
        ChangeDir (ChangeDirCmd.ChangeDir args) ->
            ChangeDirCmd.init
                args
                { fs = dir
                }
                |> map ChangeDirProc ChangeDirProcMsg
            
        MakeDir (MakeDirCmd.MakeDir args) ->
            MakeDirCmd.init
                args
                { fs = dir
                }
                |> map MakeDirProc MakeDirProcMsg
            
        Remove (RemoveCmd.Remove args) ->
            RemoveCmd.init
                args
                { fs = dir
                }
                |> map RemoveProc RemoveProcMsg
        
        Concat (ConcatCmd.Concat args) ->
            ConcatCmd.init
                args
                { fs = dir
                }
                |> map ConcatProc ConcatProcMsg
            
        Sleep (SleepCmd.Sleep args) ->
            SleepCmd.init
                args
                ()
                |> map SleepProc SleepProcMsg
                
        CmdErr err ->
            (State.Error Stay err, Cmd.none)
                
        _ ->
            (State.Exit Stay, Cmd.none)
                

run : ProcessMsg -> Process -> (ProcState Process, Cmd ProcessMsg)
run msg proc =
    case (msg, proc) of
        (HelpProcMsg helpMsg, HelpProc helpProc) ->
            HelpCmd.run helpMsg helpProc
                |> map HelpProc HelpProcMsg

        (LinkProcMsg linkMsg, LinkProc linkProc) ->
            LinkCmd.run linkMsg linkProc
                |> map LinkProc LinkProcMsg
        
        (WhoAmIProcMsg whoamiMsg, WhoAmIProc whoamiProc) ->
            WhoAmICmd.run whoamiMsg whoamiProc
                |> map WhoAmIProc WhoAmIProcMsg
                
        (WorkProcMsg workMsg, WorkProc workProc) ->
            WorkCmd.run workMsg workProc
                |> map WorkProc WorkProcMsg
                
        (TouchProcMsg touchMsg, TouchProc touchProc) ->
            TouchCmd.run touchMsg touchProc
                |> map TouchProc TouchProcMsg
                
        (ChangeDirProcMsg changeDirMsg, ChangeDirProc changeDirProc) ->
            ChangeDirCmd.run changeDirMsg changeDirProc
                |> map ChangeDirProc ChangeDirProcMsg
                
        (MakeDirProcMsg makeDirMsg, MakeDirProc makeDirProc) ->
            MakeDirCmd.run makeDirMsg makeDirProc
                |> map MakeDirProc MakeDirProcMsg
            
        (RemoveProcMsg removeMsg, RemoveProc removeProc) ->
            RemoveCmd.run removeMsg removeProc
                |> map RemoveProc RemoveProcMsg
        
        (ConcatProcMsg concatMsg, ConcatProc concatProc) ->
            ConcatCmd.run concatMsg concatProc
                |> map ConcatProc ConcatProcMsg
                
        (SleepProcMsg sleepMsg, SleepProc sleepProc) ->
            SleepCmd.run sleepMsg sleepProc
                |> map SleepProc SleepProcMsg

        _ ->
            (State.Exit Stay, Cmd.none)


view : Process -> Html ProcessMsg
view proc =
    case proc of
        LinkProc proc_ ->
            LinkCmd.view proc_
        
        HelpProc proc_ ->
            HelpCmd.view proc_
            
        WhoAmIProc proc_ ->
            WhoAmICmd.view proc_
            
        WorkProc proc_ ->
            WorkCmd.view proc_
            
        ListProc proc_ ->
            ListCmd.view proc_
            
        TouchProc proc_ ->
            TouchCmd.view proc_
                
        ChangeDirProc proc_ ->
            ChangeDirCmd.view proc_

        MakeDirProc proc_ ->
            MakeDirCmd.view proc_
        
        RemoveProc proc_ ->
            RemoveCmd.view proc_

        ConcatProc proc_ ->
            ConcatCmd.view proc_
            
        SleepProc proc_ ->
            SleepCmd.view proc_
                |> Html.map SleepProcMsg
            
        Stay ->
            Html.text ""
            

subscriptions : Process -> Sub ProcessMsg
subscriptions proc =
    case proc of
        SleepProc proc_ ->
            SleepCmd.subscriptions proc_
                |> Sub.map SleepProcMsg

        _ -> Sub.none
        

getFS : Process -> Maybe (Zipper FileSystem)
getFS proc =
    case proc of
        TouchProc proc_ ->
            Just proc_.fs

        ChangeDirProc proc_ ->
            Just proc_.fs
            
        MakeDirProc proc_ ->
            Just proc_.fs
        
        RemoveProc proc_ ->
            Just proc_.fs
            
        _ ->
            Nothing
        

map : (proc -> Process) -> (msg -> ProcessMsg) -> (ProcState proc, Cmd msg) -> (ProcState Process, Cmd ProcessMsg)
map procFunc msgFunc (st, cmd) =
    (State.map procFunc st, Cmd.map msgFunc cmd)


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
