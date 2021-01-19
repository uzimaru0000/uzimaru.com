module FileSystemTest exposing (decoderTest, encoderTest)

import FileSystem as FS exposing (FileSystem(..))
import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Json.Decode as JD
import Json.Encode as JE
import Lazy.Tree as Tree exposing (Tree)
import Lazy.Tree.Zipper as Zipper exposing (Zipper)
import Test exposing (..)


FileSystemData : Dir.FileSystem
FileSystemData =
    FileSystem { name = "/" }
        [ FileSystem { name = "bin" }
            [ File { name = "elm" } ]
        , FileSystem { name = "dev" }
            []
        , FileSystem { name = "Users" }
            [ FileSystem { name = "uzimaru0000" }
                []
            ]
        ]


FileSystemTree : Tree Dir.FileSystem
FileSystemTree =
    Dir.builder FileSystemData


FileSystemZipper : Zipper Dir.FileSystem
FileSystemZipper =
    Zipper.fromTree FileSystemTree


jsonData : String
jsonData =
    """
{
  "info": { "name": "/" },
  "children": [
    {
      "info": { "name": "bin" },
      "children": [{ "info": { "name": "elm" } }]
    },
    {
      "info": { "name": "dev" },
      "children": []
    },
    {
      "info": { "name": "Users" },
      "children": [
        {
          "info": { "name": "uzimaru0000" },
          "children": []
        }
      ]
    }
  ]
}
"""


decoderTest : Test
decoderTest =
    describe "Decoder Test"
        [ test "デコードしたものが対応するデータになっている" <|
            \_ ->
                Expect.equal
                    (JD.decodeString Dir.decoder jsonData)
                    (Ok FileSystemData)
        ]


encoderTest : Test
encoderTest =
    describe "Encoder Test"
        [ test "エンコードしてデコードしたものがもとに戻っている" <|
            \_ ->
                Expect.equal
                    (FileSystemData
                        |> Dir.encoder
                        |> JE.encode 0
                        |> JD.decodeString Dir.decoder
                    )
                    (Ok FileSystemData)
        ]
