module Analyser.Fixes.TestUtil exposing (testFix)

import Analyser.Checks.Base exposing (Checker)
import Analyser.Configuration as Configuration
import Analyser.Fixes.Base exposing (Fixer)
import Elm.Interface as Interface
import Elm.Parser as Parser
import Elm.Processing as Processing
import Elm.RawFile as RawFile exposing (RawFile)
import Elm.Syntax.File exposing (File)
import Expect
import Test exposing (Test, describe, test)


analyseAndFix : Checker -> Fixer -> String -> RawFile -> File -> Result String String
analyseAndFix checker fixer input rawFile f =
    let
        fileContext =
            { interface = Interface.build rawFile
            , moduleName = RawFile.moduleName rawFile
            , ast = f
            , content = input
            , file =
                { path = "./Foo.elm"
                , version = "xxx"
                }
            , formatted = True
            }

        x =
            checker.check fileContext Configuration.defaultConfiguration
    in
    case x of
        [] ->
            Err "No message"

        x :: _ ->
            fixer.fix ( fileContext.content, fileContext.ast ) x


testFix : String -> Checker -> Fixer -> List ( String, String, String ) -> Test
testFix name checker fixer triples =
    describe name <|
        List.map
            (\( testName, input, output ) ->
                test testName <|
                    \() ->
                        Parser.parse input
                            |> Result.mapError (always "Parse Failed")
                            |> Result.andThen
                                (\x ->
                                    analyseAndFix checker
                                        fixer
                                        input
                                        x
                                        (Processing.process Processing.init x)
                                )
                            |> Expect.equal (Ok output)
            )
        <|
            triples
