#!/usr/bin/env -S ost .

Copyright 2022 ComdivByZero

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

MODULE odcey;

IMPORT
  log,
  CLI,
  Odc,
  Stream := VDataStream,
  File := VFileStream,
  VDefaultIO,
  Chars0X,
  Utf8;

CONST
  Version* = "0.d.0";

PROCEDURE Help(cli: BOOLEAN);
BEGIN
  log.sn("odcey - convert .odc to plain text");
  log.n;
  log.sn("Usage:");
  IF cli THEN
    log.sn(" 0. odcey text       <input> <output>");
    log.sn(" 1. odcey add-to-git <dir>")
  ELSE
    log.sn(" 0. odcey.text(input, output)");
    log.sn(" 1. odcey.addToGit(dir)")
  END;
  log.n;
  log.sn("0. print text content of .odc, empty arguments for standard IO");
  log.sn("1. integrate to git repo as text converter");
END Help;

PROCEDURE Text(input, output: ARRAY OF CHAR): BOOLEAN;
VAR ok: BOOLEAN; in: Stream.PIn; out: Stream.POut; doc: Odc.Document;
BEGIN
  IF input # "" THEN
    in := File.OpenIn(input)
  ELSE
    in := VDefaultIO.OpenIn()
  END;
  ok := (in # NIL) & Odc.ReadDoc(in^, doc);
  IF in = NIL THEN
    log.sn("Can not open input")
  ELSIF ~ok THEN
    log.sn("Error during parsing input as .odc")
  ELSE
    IF output = "" THEN
      out := VDefaultIO.OpenOut()
    ELSE
      out := File.OpenOut(output)
    END;
    ok := (out # NIL) & Odc.PrintDoc(out^, doc);
    IF out = NIL THEN
      log.sn("Can not open output")
    ELSIF ~ok THEN
      log.sn("Error during printing to output")
    END
  END;
  Stream.CloseIn(in);
  Stream.CloseOut(out)
RETURN
  ok
END Text;

PROCEDURE ConcatPath(VAR res: ARRAY OF CHAR; dir, file: ARRAY OF CHAR): BOOLEAN;
VAR len: INTEGER;
BEGIN
  len := 0
RETURN
   (    (dir = "")
    OR  Chars0X.CopyString(res, len, dir)
      & Chars0X.CopyString(res, len, "/")
   )
 & Chars0X.CopyString(res, len, file)
END ConcatPath;

PROCEDURE AddToGit(gitDir: ARRAY OF CHAR): BOOLEAN;
VAR ok: BOOLEAN; attrs, config: File.Out; str: ARRAY 64 OF CHAR; len: INTEGER;

  PROCEDURE Open(dir, file: ARRAY OF CHAR): File.Out;
  VAR path: ARRAY 4096 OF CHAR; out: File.Out;
  BEGIN
    IF ConcatPath(path, dir, file) THEN
      out := File.OpenForAppend(path)
    ELSE
      out := NIL
    END;
    IF out = NIL THEN
      log.s("Can not open '");
      log.s(path);
      log.sn("'")
    END
  RETURN
    out
  END Open;
BEGIN
  attrs  := Open(gitDir, ".git/info/attributes");
  config := Open(gitDir, ".git/config");
  ok := (attrs # NIL) & (config # NIL);
  IF ok THEN
    len := 0;
    ASSERT(Chars0X.PutChar   (str, len, Utf8.NewLine)
         & Chars0X.CopyString(str, len, "*.odc diff=cp")
         & Chars0X.PutChar   (str, len, Utf8.NewLine));
    ok := len = Stream.WriteChars(attrs^, str, 0, len);
    IF ~ok THEN
      log.sn("Can not edit .git/info/attributes")
    ELSE
      len := 0;
      ASSERT(Chars0X.PutChar   (str, len, Utf8.NewLine)
           & Chars0X.CopyString(str, len, "[diff ")
           & Chars0X.PutChar   (str, len, Utf8.DQuote)
           & Chars0X.CopyString(str, len, "cp")
           & Chars0X.PutChar   (str, len, Utf8.DQuote)
           & Chars0X.PutChar   (str, len, "]")
           & Chars0X.PutChar   (str, len, Utf8.NewLine)
           & Chars0X.CopyString(str, len, "	binary = true")
           & Chars0X.PutChar   (str, len, Utf8.NewLine)
           & Chars0X.CopyString(str, len, "	textconv = odcey text <")
           & Chars0X.PutChar   (str, len, Utf8.NewLine));
      ok := len = Stream.WriteChars(config^, str, 0, len);
      IF ~ok THEN
        log.sn("Can not edit .git/config")
      END
    END
  END;
  File.CloseOut(attrs);
  File.CloseOut(config);
RETURN
  FALSE
END AddToGit;

PROCEDURE help*;
BEGIN
  Help(FALSE)
END help;

PROCEDURE text*(input, output: ARRAY OF CHAR);
VAR ignore: BOOLEAN;
BEGIN
  ignore := Text(input, output)
END text;

PROCEDURE addToGit*(gitDir: ARRAY OF CHAR);
VAR ignore: BOOLEAN;
BEGIN
  ignore := AddToGit(gitDir)
END addToGit;

PROCEDURE Cli*;
VAR
  arg, arg2: ARRAY CLI.MaxLen + 1 OF CHAR;
  len: INTEGER;
  ok: BOOLEAN;
BEGIN
  ok := TRUE;
  len := 0;
  IF (CLI.count = 0) OR ~CLI.Get(arg, len, 0) THEN
    ok := FALSE;
    Help(TRUE)
  ELSIF arg = "help" THEN
    Help(TRUE)
  ELSIF arg = "version" THEN
    log.sn(Version)
  ELSIF arg = "text" THEN
    arg := "";
    arg2 := "";
    IF CLI.count > 1 THEN
      len := 0;
      ASSERT(CLI.Get(arg, len, 0));
      IF CLI.count = 3 THEN
        len := 0;
        ASSERT(CLI.Get(arg2, len, 0))
      ELSE
        ok := FALSE;
        log.sn("Too many arguments for text")
      END
    END;
    ok := ok & Text(arg, arg2)
  ELSIF arg = "add-to-git" THEN
    IF CLI.count = 1 THEN
      ok := AddToGit("")
    ELSIF CLI.count = 2 THEN
      len := 0;
      ASSERT(CLI.Get(arg, len, 1));
      len := Chars0X.Trim(arg, 0);
      ok := AddToGit(arg);
    ELSE
      ok := FALSE;
      log.sn("Too many arguments for add-to-git")
    END
  ELSE
    ok := FALSE;
    log.s("Wrong command '"); log.s(arg); log.sn("'")
  END;
  CLI.SetExitCode(1 - ORD(ok))
END Cli;

END odcey.
