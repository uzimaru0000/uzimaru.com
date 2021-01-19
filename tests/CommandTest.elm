module CommandTest exposing (..)

import Command exposing (..)
import Command.Help as HelpCmd
import Command.Link as LinkCmd
import Command.WhoAmI as WhoAmICmd
import Command.Work as WorkCmd
import FileSystem exposing (FileSystem(..))
import Expect exposing (Expectation)
import Fuzz
import Lazy.Tree.Zipper as Zipper exposing (Zipper)
import Parser
import Random
import Shrink
import Test exposing (..)


dirZipper : Zipper FileSystem
dirZipper =
    FileSystem { name = "/" }
        [ FileSystem { name = "bin" }
            [ File { name = "elm" }
            ]
        , FileSystem { name = "dev" }
            []
        , FileSystem { name = "usr" }
            []
        , FileSystem { name = "Users" }
            [ FileSystem { name = "uzimaru0000" }
                []
            ]
        , File { name = "test.txt" }
        ]
        |> FileSystem.builder
        |> Zipper.fromTree


-- testRemove : Test
-- testRemove =
--     describe "Remove test"
--         [ test "test.txt を削除" <|
--             \_ ->
--                 case remove [ "test.txt" ] dirZipper of
--                     Ok dir ->
--                         Expect.equal
--                             (Zipper.open (FileSystem.getName >> (==) "test.txt") dir)
--                             Nothing

--                     Err error ->
--                         Expect.fail error
--         , test "dev/ を削除（オプションが無いので失敗）" <|
--             \_ ->
--                 case remove [ "dev" ] dirZipper of
--                     Ok _ ->
--                         Expect.fail "オプションがないので失敗しないといけません"

--                     Err _ ->
--                         Expect.pass
--         , test "dev/ を削除 （オプションあり）" <|
--             \_ ->
--                 case remove [ "-r", "dev" ] dirZipper of
--                     Ok dir ->
--                         Expect.equal
--                             (Zipper.open (FileSystem.getName >> (==) "dev") dir)
--                             Nothing

--                     Err err ->
--                         Expect.fail err
--         , test "bin/elm を削除" <|
--             \_ ->
--                 case remove [ "bin/elm" ] dirZipper of
--                     Ok dir ->
--                         Expect.err
--                             (Zipper.openPath (\p d -> p == FileSystem.getName d) [ "bin", "elm" ] dir)

--                     Err err ->
--                         Expect.fail err
--         , test "Users/ を削除（再帰的な削除）" <|
--             \_ ->
--                 case remove [ "-r", "Users" ] dirZipper of
--                     Ok dir ->
--                         dir
--                             |> Expect.all
--                                 [ \x ->
--                                     Expect.equal
--                                         (Zipper.open (FileSystem.getName >> (==) "Users") x)
--                                         Nothing
--                                 , \x ->
--                                     Expect.err
--                                         (Zipper.openPath
--                                             (\p d -> p == FileSystem.getName d)
--                                             [ "Users", "uzimaru0000" ]
--                                             x
--                                         )
--                                 ]

--                     Err err ->
--                         Expect.fail err
--         ]


-- testChangeDir : Test
-- testChangeDir =
--     describe "cd test"
--         [ test "Users/ に移動" <|
--             \_ ->
--                 case changeDir [ "Users" ] dirZipper of
--                     Ok dir ->
--                         Expect.equal
--                             (Zipper.current dir |> FileSystem.getName)
--                             "Users"

--                     Err err ->
--                         Expect.fail err
--         , test "Users/uzimaru0000/ に移動" <|
--             \_ ->
--                 case changeDir [ "Users/uzimaru0000" ] dirZipper of
--                     Ok dir ->
--                         Expect.equal
--                             (Zipper.current dir |> FileSystem.getName)
--                             "uzimaru0000"

--                     Err err ->
--                         Expect.fail err
--         , test "存在しないディレクトリに移動" <|
--             \_ ->
--                 changeDir [ "hoge" ] dirZipper
--                     |> Expect.err
--         , test "Users/.. に移動" <|
--             \_ ->
--                 case changeDir [ "Users/.." ] dirZipper of
--                     Ok dir ->
--                         Expect.equal
--                             (Zipper.current dir |> FileSystem.getName)
--                             "/"

--                     Err err ->
--                         Expect.fail err
--         , test "./Users に移動" <|
--             \_ ->
--                 case changeDir [ "./Users" ] dirZipper of
--                     Ok dir ->
--                         Expect.equal
--                             (Zipper.current dir |> FileSystem.getName)
--                             "Users"

--                     Err err ->
--                         Expect.fail err
--         , test "ルートに移動" <|
--             \_ ->
--                 case dirZipper |> changeDir [ "Users" ] |> Result.andThen (changeDir []) of
--                     Ok dir ->
--                         Expect.true "" <| Zipper.isRoot dir

--                     Err err ->
--                         Expect.fail err
--         , test "ファイルに移動しようとする（エラー）" <|
--             \_ ->
--                 Expect.err <| changeDir [ "test.txt" ] dirZipper
--         ]


commandString : String -> Fuzz.Fuzzer String
commandString str =
    let
        generator =
            Random.list (String.length str) (Random.float 0.0 1.0 |> Random.map ((>) 0.5))
                |> Random.map2
                    (List.map2
                        (\c f ->
                            if f then
                                Char.toUpper c

                            else
                                c
                        )
                    )
                    (Random.constant (String.toList str))
                |> Random.map String.fromList
    in
    Fuzz.custom generator (\s -> Shrink.noShrink s)


testHelpCommand : Test
testHelpCommand =
    describe "Help Command Test"
        [ test "`help` をparseできる" <|
            \_ ->
                Parser.run HelpCmd.parser "help"
                    |> Expect.equal (Ok <| HelpCmd.Help)
        ]


testWhoAmICommand : Test
testWhoAmICommand =
    describe "WhoAmI Command Test"
        [ test "`whoami` をparseできる" <|
            \str ->
                Parser.run WhoAmICmd.parser "whoami"
                    |> Expect.equal (Ok <| WhoAmICmd.WhoAmI { help = False })
        ]


testWorkCommand : Test
testWorkCommand =
    describe "work Command Test"
        [ test "`work` をparseできる" <|
            \_ ->
               Parser.run WorkCmd.parser "work"
                    |> Expect.equal (Ok <| WorkCmd.Work { yes = False, help = False, param = Nothing })
        , test "`work --yes` をparseできる" <|
            \_ ->
                Parser.run WorkCmd.parser "work --yes"
                    |> Expect.equal (Ok <| WorkCmd.Work { yes = True, help = False, param = Nothing })
        ]


testLinkCommand : Test
testLinkCommand =
    describe "link Command Test"
        [ test "`link` をparseできる" <|
            \_ ->
               Parser.run LinkCmd.parser "link"
                    |> Expect.equal (Ok <| LinkCmd.Link { help = False, param = Nothing })
        ]
