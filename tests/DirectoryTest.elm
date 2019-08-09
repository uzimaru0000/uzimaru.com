module DirectoryTest exposing (decoderTest, encoderTest)

import Directory as Dir exposing (Directory(..))
import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Json.Decode as JD
import Json.Encode as JE
import Test exposing (..)


directoryData : Dir.Directory
directoryData =
    Directory { name = "/" }
        [ Directory { name = "bin" }
            [ File { name = "elm" } ]
        , Directory { name = "dev" }
            []
        , Directory { name = "Users" }
            [ Directory { name = "uzimaru0000" }
                []
            ]
        ]


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
                    (Ok directoryData)
        ]


encoderTest : Test
encoderTest =
    describe "Encoder Test"
        [ test "エンコードしてデコードしたものがもとに戻っている" <|
            \_ ->
                Expect.equal
                    (directoryData
                        |> Dir.encoder
                        |> JE.encode 0
                        |> JD.decodeString Dir.decoder
                    )
                    (Ok directoryData)
        ]
