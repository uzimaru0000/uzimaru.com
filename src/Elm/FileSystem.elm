module FileSystem exposing
    ( FileSystem(..)
    , Error(..)
    , Directory
    , File
    , Info
    , builder
    , decoder
    , dismantlers
    , encoder
    , getName
    , pwd
    , cwd
    , readFile
    , writeFile
    , errorToString
    )

import Html exposing (..)
import Json.Decode as JD
import Json.Encode as JE
import Lazy.LList as LList
import Lazy.Tree as Tree exposing (Tree)
import Lazy.Tree.Zipper as Zipper exposing (Zipper)
import Lazy.Tree.Zipper exposing (children)
import Bytes exposing (Bytes)
import Bytes.Decode as BD
import Bytes.Encode as BE


type FileSystem 
    = Directory_ Directory
    | File_ File


type alias Directory =
    { info: Info
    , children: List FileSystem
    }


type alias File =
    { info: Info
    , data: Bytes
    }


type alias Info =
    { name : String
    }


type Error
    = NotExist
    | TargetIsFile
    | TargetIsFileSystem
    | InvalidPath
    | InvalidData
    

builder : FileSystem -> Tree FileSystem
builder =
    Tree.build
        (\x ->
            case x of
                Directory_ dir ->
                    dir.children

                File_ _ ->
                    []
        )


dismantlers : Tree FileSystem -> FileSystem
dismantlers tree =
    let
        dir =
            Tree.item tree

        children =
            Tree.descendants tree
    in
    case dir of
        Directory_ { info } ->
            children
                |> LList.map dismantlers
                |> LList.toList
                |> \c -> { children = c, info = info }
                |> Directory_

        File_ file ->
            File_ file


getName : FileSystem -> String
getName dir =
    case dir of
        Directory_ { info } ->
            info.name

        File_ { info } ->
            info.name


pwd : Zipper FileSystem -> String
pwd =
    Zipper.getPath getName >> String.join "/"


cwd : List String -> Zipper FileSystem -> Result Error (Zipper FileSystem)
cwd path dir =
    case path of
        ".." :: tail ->
            dir
                |> Zipper.up
                |> Result.fromMaybe NotExist
                |> Result.andThen (cwd tail)

        "." :: tail ->
            cwd tail dir

        head :: tail ->
            dir
                |> Zipper.open
                    (\x ->
                        case x of
                            Directory_ { info } ->
                                info.name == head

                            File_ _ ->
                                False
                    )
                |> Result.fromMaybe
                    (case Zipper.open (getName >> (==) head) dir |> Maybe.map Zipper.current of
                        Just (File_ _) ->
                            TargetIsFile

                        Nothing ->
                            NotExist

                        _ ->
                            NotExist
                    )
                |> Result.andThen (cwd tail)

        [] ->
            Ok dir


readFile : List String -> Zipper FileSystem -> Result Error File
readFile path dir =
    dir
        |> Zipper.openPath (\x y -> x == getName y) path
        |> Result.map Zipper.current
        |> Result.mapError (always NotExist)
        |> Result.andThen
            (\x ->
                case x of
                    Directory_ _ -> Err TargetIsFileSystem
                    File_ file -> Ok file
            )


writeFile : List String -> Bytes -> Zipper FileSystem -> Result Error (Zipper FileSystem)
writeFile path data dir =
    dir
        |> Zipper.openPath (\x y -> x == getName y) path
        |> Result.mapError (always NotExist)
        |> Result.map
            (Zipper.updateItem
                (\x ->
                    case x of
                        File_ file ->
                            File_
                                { file
                                    | data = data   
                                }
                        _ ->
                            x
                )
            )
        |> Result.andThen (Zipper.up >> Result.fromMaybe NotExist)

infoDecoder : JD.Decoder Info
infoDecoder =
    JD.map Info
        (JD.field "name" JD.string)


infoEncoder : Info -> JE.Value
infoEncoder info =
    JE.object
        [ ( "name", JE.string info.name )
        ]


fileContentDecoder : Int -> BD.Decoder (List Int)
fileContentDecoder len =
    BD.loop (len, []) fileContentDecoderStep


fileContentDecoderStep : (Int, List Int) -> BD.Decoder (BD.Step (Int, List Int) (List Int))
fileContentDecoderStep (n, xs) =
    if n <= 0 then
        BD.succeed (BD.Done xs)
    else
        BD.signedInt8
            |> BD.map (\x -> BD.Loop (n - 1, x :: xs))



fileContentEncoder : List Int -> BE.Encoder
fileContentEncoder buffer =
    BE.sequence
        (buffer
            |> List.map BE.signedInt8
        )


decoder : JD.Decoder FileSystem
decoder =
    JD.oneOf
        [ JD.map Directory_
            (JD.map2 Directory
                (JD.field "info" infoDecoder)
                (JD.field "children" <| JD.list <| JD.lazy (\_ -> decoder))
            )
        , JD.map File_
            (JD.map2 File
                (JD.field "info" infoDecoder)
                (JD.list JD.int
                    |> JD.field "data"
                    |> JD.map (fileContentEncoder >> BE.encode)
                )
            )
        ]


encoder : FileSystem -> JE.Value
encoder dir =
    case dir of
        Directory_ ({ info, children }) ->
            JE.object
                [ ( "info", infoEncoder info )
                , ( "children", JE.list encoder children )
                ]

        File_ { info, data } ->
            JE.object
                [ ( "info", infoEncoder info )
                , ( "data"
                  , data
                        |> BD.decode (fileContentDecoder (Bytes.width data))
                        |> Maybe.withDefault []
                        |> JE.list JE.int
                  )
                ]


errorToString : Error -> String
errorToString err =
    case err of
        NotExist ->
            "File is not exist"
        InvalidPath ->
            "Path is invalid"
        InvalidData ->
            "Data is invalid"
        TargetIsFile ->
            "Target is file"
        TargetIsFileSystem ->
            "Target is directory"
