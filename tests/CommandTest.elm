module CommandTest exposing
    ( testChangeDir
    , testHelpCommand
    , testLinkCommand
    , testRemove
    , testWhoAmICommand
    , testWorkCommand
    )

import Command exposing (..)
import Command.Help as HelpCmd
import Command.Link as LinkCmd
import Command.WhoAmI as WhoAmICmd
import Command.Work as WorkCmd
import Directory exposing (Directory(..))
import Expect exposing (Expectation)
import Fuzz
import Lazy.Tree.Zipper as Zipper exposing (Zipper)
import Parser
import Random
import Shrink
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
                    |> Expect.equal (Ok <| HelpCmd.Help (HelpCmd.Args Nothing))
        , test "`help whomai` をparseできる" <|
            \_ ->
                Parser.run HelpCmd.parser "help whoami"
                    |> Expect.equal (Ok <| HelpCmd.Help (HelpCmd.Args <| Just "whoami"))
        ]


testWhoAmICommand : Test
testWhoAmICommand =
    describe "WhoAmI Command Test"
        [ fuzz (commandString "whoami") "`whoami` をparseできる" <|
            \str ->
                Parser.run WhoAmICmd.parser str
                    |> Expect.equal (Ok <| WhoAmICmd.WhoAmI)
        ]


testWorkCommand : Test
testWorkCommand =
    describe "work Command Test"
        [ fuzz (commandString "work") "`work` をparseできる" <|
            \str ->
                Parser.run WorkCmd.parser str
                    |> Expect.equal (Ok <| WorkCmd.Work (WorkCmd.Args False Nothing))
        , fuzz (commandString "work") "`work -y` をparseできる" <|
            \str ->
                Parser.run WorkCmd.parser (str ++ " -y")
                    |> Expect.equal (Ok <| WorkCmd.Work (WorkCmd.Args True Nothing))
        , fuzz (commandString "work") "`work --yes` をparseできる" <|
            \str ->
                Parser.run WorkCmd.parser (str ++ " --yes")
                    |> Expect.equal (Ok <| WorkCmd.Work (WorkCmd.Args True Nothing))
        , test "`work splash` をparseできる" <|
            \_ ->
                Parser.run WorkCmd.parser "work splash"
                    |> Expect.equal (Ok <| WorkCmd.Work (WorkCmd.Args False (Just "splash")))
        , test "`work -y splash` をparseできる" <|
            \_ ->
                Parser.run WorkCmd.parser "work -y splash"
                    |> Expect.equal (Ok <| WorkCmd.Work (WorkCmd.Args True (Just "splash")))
        , test "`work splash -y` をparseできる" <|
            \_ ->
                Parser.run WorkCmd.parser "work -y splash"
                    |> Expect.equal (Ok <| WorkCmd.Work (WorkCmd.Args True (Just "splash")))
        , test "`work --yes splash` をparseできる" <|
            \_ ->
                Parser.run WorkCmd.parser "work --yes splash"
                    |> Expect.equal (Ok <| WorkCmd.Work (WorkCmd.Args True (Just "splash")))
        , test "`work splash --yes` をparseできる" <|
            \_ ->
                Parser.run WorkCmd.parser "work splash --yes"
                    |> Expect.equal (Ok <| WorkCmd.Work (WorkCmd.Args True (Just "splash")))
        ]


testLinkCommand : Test
testLinkCommand =
    describe "link Command Test"
        [ fuzz (commandString "link") "`link` をparseできる" <|
            \str ->
                Parser.run LinkCmd.parser str
                    |> Expect.equal (Ok <| LinkCmd.Link (LinkCmd.Args False Nothing))
        , fuzz (commandString "link") "`link -y` をparseできる" <|
            \str ->
                Parser.run LinkCmd.parser (str ++ " -y")
                    |> Expect.equal (Ok <| LinkCmd.Link (LinkCmd.Args True Nothing))
        , fuzz (commandString "link") "`link --yes` をparseできる" <|
            \str ->
                Parser.run LinkCmd.parser (str ++ " --yes")
                    |> Expect.equal (Ok <| LinkCmd.Link (LinkCmd.Args True Nothing))
        , test "`link twitter` をparseできる" <|
            \_ ->
                Parser.run LinkCmd.parser "link twitter"
                    |> Expect.equal (Ok <| LinkCmd.Link (LinkCmd.Args False (Just "twitter")))
        , test "`link -y twitter` をparseできる" <|
            \_ ->
                Parser.run LinkCmd.parser "link -y twitter"
                    |> Expect.equal (Ok <| LinkCmd.Link (LinkCmd.Args True (Just "twitter")))
        , test "`link twitter -y` をparseできる" <|
            \_ ->
                Parser.run LinkCmd.parser "link twitter -y"
                    |> Expect.equal (Ok <| LinkCmd.Link (LinkCmd.Args True (Just "twitter")))
        , test "`link --yes twitter` をparseできる" <|
            \_ ->
                Parser.run LinkCmd.parser "link --yes twitter"
                    |> Expect.equal (Ok <| LinkCmd.Link (LinkCmd.Args True (Just "twitter")))
        , test "`link twitter --yes` をparseできる" <|
            \_ ->
                Parser.run LinkCmd.parser "link twitter --yes"
                    |> Expect.equal (Ok <| LinkCmd.Link (LinkCmd.Args True (Just "twitter")))
        ]
