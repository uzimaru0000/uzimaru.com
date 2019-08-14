module CommandTest exposing
    ( testChangeDir
    , testCommandToString
    , testRemove
    )

import Command exposing (..)
import Directory exposing (Directory(..))
import Expect exposing (Expectation)
import Lazy.Tree.Zipper as Zipper exposing (Zipper)
import Test exposing (..)


dirZipper : Zipper Directory
dirZipper =
    Directory { name = "/" }
        [ Directory { name = "bin" }
            [ File { name = "elm" }
            ]
        , Directory { name = "dev" }
            []
        , Directory { name = "usr" }
            []
        , Directory { name = "Users" }
            [ Directory { name = "uzimaru0000" }
                []
            ]
        , File { name = "test.txt" }
        ]
        |> Directory.builder
        |> Zipper.fromTree


testCommandToString : Test
testCommandToString =
    describe "cmd to string"
        [ describe "Commandが対応している文字列に変換されている" <|
            ([ ( Error "hoge" "", "hoge" )
             , ( Help, "help" )
             , ( WhoAmI, "whoami" )
             , ( Work, "work" )
             , ( Link, "link" )
             , ( List, "ls" )
             , ( MakeDir, "mkdir" )
             , ( Touch, "touch" )
             , ( ChangeDir, "cd" )
             , ( Remove, "rm" )
             ]
                |> List.map
                    (\( cmd, str ) ->
                        test (str ++ " command") <|
                            \_ ->
                                Expect.equal
                                    (commandToString cmd)
                                    str
                    )
            )
        ]


testRemove : Test
testRemove =
    describe "Remove test"
        [ test "test.txt を削除" <|
            \_ ->
                case remove [ "test.txt" ] dirZipper of
                    Ok dir ->
                        Expect.equal
                            (Zipper.open (Directory.getName >> (==) "test.txt") dir)
                            Nothing

                    Err error ->
                        Expect.fail error
        , test "dev/ を削除（オプションが無いので失敗）" <|
            \_ ->
                case remove [ "dev" ] dirZipper of
                    Ok _ ->
                        Expect.fail "オプションがないので失敗しないといけません"

                    Err _ ->
                        Expect.pass
        , test "dev/ を削除 （オプションあり）" <|
            \_ ->
                case remove [ "-r", "dev" ] dirZipper of
                    Ok dir ->
                        Expect.equal
                            (Zipper.open (Directory.getName >> (==) "dev") dir)
                            Nothing

                    Err err ->
                        Expect.fail err
        , test "bin/elm を削除" <|
            \_ ->
                case remove [ "bin/elm" ] dirZipper of
                    Ok dir ->
                        Expect.err
                            (Zipper.openPath (\p d -> p == Directory.getName d) [ "bin", "elm" ] dir)

                    Err err ->
                        Expect.fail err
        , test "Users/ を削除（再帰的な削除）" <|
            \_ ->
                case remove [ "-r", "Users" ] dirZipper of
                    Ok dir ->
                        dir
                            |> Expect.all
                                [ \x ->
                                    Expect.equal
                                        (Zipper.open (Directory.getName >> (==) "Users") x)
                                        Nothing
                                , \x ->
                                    Expect.err
                                        (Zipper.openPath
                                            (\p d -> p == Directory.getName d)
                                            [ "Users", "uzimaru0000" ]
                                            x
                                        )
                                ]

                    Err err ->
                        Expect.fail err
        ]


testChangeDir : Test
testChangeDir =
    describe "cd test"
        [ test "Users/ に移動" <|
            \_ ->
                case changeDir [ "Users" ] dirZipper of
                    Ok dir ->
                        Expect.equal
                            (Zipper.current dir |> Directory.getName)
                            "Users"

                    Err err ->
                        Expect.fail err
        , test "Users/uzimaru0000/ に移動" <|
            \_ ->
                case changeDir [ "Users/uzimaru0000" ] dirZipper of
                    Ok dir ->
                        Expect.equal
                            (Zipper.current dir |> Directory.getName)
                            "uzimaru0000"

                    Err err ->
                        Expect.fail err
        , test "存在しないディレクトリに移動" <|
            \_ ->
                changeDir [ "hoge" ] dirZipper
                    |> Expect.err
        , test "Users/.. に移動" <|
            \_ ->
                case changeDir [ "Users/.." ] dirZipper of
                    Ok dir ->
                        Expect.equal
                            (Zipper.current dir |> Directory.getName)
                            "/"

                    Err err ->
                        Expect.fail err
        , test "./Users に移動" <|
            \_ ->
                case changeDir [ "./Users" ] dirZipper of
                    Ok dir ->
                        Expect.equal
                            (Zipper.current dir |> Directory.getName)
                            "Users"

                    Err err ->
                        Expect.fail err
        , test "ルートに移動" <|
            \_ ->
                case dirZipper |> changeDir [ "Users" ] |> Result.andThen (changeDir []) of
                    Ok dir ->
                        Expect.true "" <| Zipper.isRoot dir

                    Err err ->
                        Expect.fail err
        , test "ファイルに移動しようとする（エラー）" <|
            \_ ->
                Expect.err <| changeDir [ "test.txt" ] dirZipper
        ]
