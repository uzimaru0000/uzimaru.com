module Directory exposing (Directory(..), Info, builder, decoder, dismantlers, encoder, getName, prompt)

import Html exposing (..)
import Json.Decode as JD
import Json.Encode as JE
import Lazy.LList as LList
import Lazy.Tree as Tree exposing (Tree)
import Lazy.Tree.Zipper as Zipper exposing (Zipper)


type Directory
    = Directory Info (List Directory)
    | File Info


type alias Info =
    { name : String
    }


builder : Directory -> Tree Directory
builder =
    Tree.build
        (\x ->
            case x of
                Directory _ children ->
                    children

                File _ ->
                    []
        )


dismantlers : Tree Directory -> Directory
dismantlers tree =
    let
        dir =
            Tree.item tree

        children =
            Tree.descendants tree
    in
    case dir of
        Directory info child ->
            children
                |> LList.map dismantlers
                |> LList.toList
                |> Directory info

        File info ->
            File info


getName : Directory -> String
getName dir =
    case dir of
        Directory { name } _ ->
            name

        File { name } ->
            name


prompt : Zipper Directory -> Html msg
prompt dir =
    span []
        [ [ "[ "
          , dir
                |> Zipper.getPath getName
                |> String.join "/"
          , " ]"
          , " $ "
          ]
            |> String.join ""
            |> text
        ]


infoDecoder : JD.Decoder Info
infoDecoder =
    JD.map Info
        (JD.field "name" JD.string)


infoEncoder : Info -> JE.Value
infoEncoder info =
    JE.object
        [ ( "name", JE.string info.name )
        ]


decoder : JD.Decoder Directory
decoder =
    JD.oneOf
        [ JD.map2 Directory
            (JD.field "info" infoDecoder)
            (JD.field "children" <| JD.list <| JD.lazy (\_ -> decoder))
        , JD.map File
            (JD.field "info" infoDecoder)
        ]


encoder : Directory -> JE.Value
encoder dir =
    case dir of
        Directory info children ->
            JE.object
                [ ( "info", infoEncoder info )
                , ( "children", JE.list encoder children )
                ]

        File info ->
            JE.object
                [ ( "info", infoEncoder info )
                ]
