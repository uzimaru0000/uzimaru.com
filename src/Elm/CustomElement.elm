module CustomElement exposing (..)

import Html exposing (Html, Attribute, node)


terminalInput : List (Attribute msg) -> List (Html msg) -> Html msg
terminalInput =
    node "terminal-input"
    

wcCodemirror : List (Attribute msg) -> List (Html msg) -> Html msg
wcCodemirror =
    node "wc-codemirror"
