module Directory exposing (..)

import Lazy.Tree as Tree exposing (Tree)
import Lazy.Tree.Zipper as Zipper exposing (Zipper)
import Html exposing (..)


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
