module Icon exposing (icon)

import Svg exposing (Svg)
import Svg.Attributes as Attrs


icon : Svg msg
icon =
    Svg.svg
        [ Attrs.class "w-fill h-fill"
        , Attrs.viewBox "0 0 512 512"
        , Attrs.fill "#c3c3c3"
        ]
        [ Svg.rect
            [ Attrs.width "512"
            , Attrs.height "512"
            , Attrs.fill "#3C3C3C"
            ]
            []
        , Svg.g
            [ Attrs.filter "url(#filter0_d)" ]
            [ Svg.path
                [ Attrs.fillRule "evenodd"
                , Attrs.clipRule "evenodd"
                , Attrs.d "M258.24 404.24C158.21 404.24 77.12 323.15 77.12 223.12C77.12 191.051 85.4547 160.928 100.076 134.8L72 82.96L137.537 88.08C169.575 59.4233 211.873 42 258.24 42C358.27 42 439.36 123.09 439.36 223.12C439.36 272.451 439.36 364.56 437.44 404.24H288.32V469.52H201.28V442.64H261.44V404.24H258.24ZM105.28 223.12C105.28 323.15 185.28 377.36 258.24 377.36H410.56V223.12C410.56 123.09 326.72 72.08 258.24 72.08C158.21 72.08 105.28 149.52 105.28 223.12Z"
                , Attrs.fill "#199861"
                ]
                []
            , Svg.path
                [ Attrs.d "M221.12 111.12C237.76 111.12 245.44 124.56 245.44 133.52C245.44 142.48 240.32 158.48 222.4 158.48C204.48 158.48 198.08 144.4 198.08 133.52C198.08 122.64 207.04 111.12 221.12 111.12Z"
                , Attrs.fill "#199861"
                ]
                []
            , Svg.path
                [ Attrs.d "M164.16 223.76C164.16 276.24 205.12 316.56 257.6 316.56V290.96C223.04 290.96 190.4 260.88 190.4 223.76H164.16Z"
                , Attrs.fill "#199861"
                ]
                []
            ]
        , Svg.defs []
            [ Svg.filter
                [ Attrs.id "filter0_d"
                , Attrs.x "56"
                , Attrs.y "26"
                , Attrs.width "399.36"
                , Attrs.height "459.52"
                , Attrs.filterUnits "userSpaceOnUse"
                , Attrs.colorInterpolationFilters "sRGB"
                ]
                [ Svg.feFlood
                    [ Attrs.floodOpacity "0"
                    , Attrs.result "BackgroundImageFix"
                    ]
                    []
                , Svg.feColorMatrix
                    [ Attrs.in_ "SourceAlpha"
                    , Attrs.type_ "matrix"
                    , Attrs.values "0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0"
                    ]
                    []
                , Svg.feOffset [] []
                , Svg.feGaussianBlur
                    [ Attrs.stdDeviation "8" ]
                    []
                , Svg.feColorMatrix
                    [ Attrs.type_ "matrix"
                    , Attrs.values "0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.25 0"
                    ]
                    []
                , Svg.feBlend
                    [ Attrs.mode "normal"
                    , Attrs.in2 "BackgroundImageFix"
                    , Attrs.result "effect1_dropShadow"
                    ]
                    []
                , Svg.feBlend
                    [ Attrs.mode "normal"
                    , Attrs.in_ "SourceGraphic"
                    , Attrs.in2 "effect1_dropShadow"
                    , Attrs.result "shape"
                    ]
                    []
                ]
            ]
        ]
