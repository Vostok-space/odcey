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
  Version* = "0.1.0";

VAR
  options: Odc.Options;

PROCEDURE Help(cli: BOOLEAN);
VAR commanderTo, skipEmbedded, skipComment, tab: ARRAY 42 OF CHAR;
BEGIN
  log.sn("odcey - converter of .odc format to plain text");
  log.n;
  log.sn("Usage:");
  IF cli THEN
    log.sn(" 0. odcey text  [input [output]] { options }");
    log.sn(" 1. odcey git   [dir]");
    commanderTo  := "-commander-to <str>";
    skipEmbedded := "-skip-embedded-view";
    skipComment  := "-skip-comment      ";
    tab          := "-tab <str>         "
  ELSE
    log.sn(" 0. odcey.text(input, output)");
    log.sn(" 1. odcey.addToGit(dir)");
    commanderTo  := "odcey.commanderTo(str)            ";
    skipEmbedded := "odcey.opt({Odc.SkipEmbeddedView })";
    skipComment  := "          {Odc.SkipOberonComment} ";
    tab          := "odcey.tab(str)                    "
  END;
  log.n;
  log.sn("0. Print text content of .odc, empty arguments for standard IO");
  log.s("   "); log.s(commanderTo); log.sn("  set Commander-view replacement");
  log.s("   "); log.s(skipEmbedded); log.sn("  skips embedded views writing");
  log.s("   "); log.s(skipComment); log.sn("  skips (* Oberon comments *) ");
  log.s("   "); log.s(tab); log.sn("  set tabulation replacement");
  log.n;
  log.sn("1. Embed to a .git repo as a text converter; empty argument for current dir")
END Help;

PROCEDURE Text(input, output: ARRAY OF CHAR; opt: Odc.Options): BOOLEAN;
VAR ok: BOOLEAN; in: Stream.PIn; out: Stream.POut; doc: Odc.Document;
BEGIN
  IF input # "" THEN
    in := File.OpenIn(input)
  ELSE
    in := VDefaultIO.OpenIn()
  END;
  IF in = NIL THEN
    log.sn("Can not open input");
    ok := FALSE
  ELSE
    ok := Odc.ReadDoc(in^, doc);
    Stream.CloseIn(in);
    IF ~ok THEN
      log.sn("Error during parsing input as .odc")
    ELSE
      IF output = "" THEN
        out := VDefaultIO.OpenOut()
      ELSE
        out := File.OpenOut(output)
      END;
      ok := (out # NIL) & Odc.PrintDoc(out^, doc, opt);
      IF out = NIL THEN
        log.sn("Can not open output")
      ELSIF ~ok THEN
        log.sn("Error during printing to output")
      END;
      Stream.CloseOut(out)
    END
  END
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

PROCEDURE commanderTo*(replacement: ARRAY OF CHAR);
BEGIN
  options.commanderReplacement := replacement
END commanderTo;

PROCEDURE opt*(set: SET);
BEGIN
  ASSERT(set - {0 .. Odc.LastOption} = {});
  options.set := set
END opt;

PROCEDURE tab*(str: ARRAY OF CHAR);
BEGIN
  options.tab := str
END tab;

PROCEDURE text*(input, output: ARRAY OF CHAR);
VAR ignore: BOOLEAN;
BEGIN
  ignore := Text(input, output, options)
END text;

PROCEDURE addToGit*(gitDir: ARRAY OF CHAR);
VAR ignore: BOOLEAN;
BEGIN
  ignore := AddToGit(gitDir)
END addToGit;

PROCEDURE Cli*;
VAR
  args: ARRAY 2 OF ARRAY CLI.MaxLen + 1 OF CHAR; tabOpt: ARRAY LEN(options.tab) OF CHAR;
  len, i, argInd: INTEGER;
  ok: BOOLEAN;

  PROCEDURE Option(VAR ind: INTEGER; par: ARRAY OF CHAR; VAR arg: ARRAY OF CHAR;
                   VAR ok: BOOLEAN): BOOLEAN;
  VAR match: BOOLEAN; buf: ARRAY 16 OF CHAR; ofs: INTEGER;
  BEGIN
    ofs := 0;
    match := (ind < CLI.count) & CLI.Get(buf, ofs, ind) & (buf = par);
    IF match THEN
      INC(ind);
      ofs := 0;
      ok := FALSE;
      IF ind = CLI.count THEN
        log.s("Absent argument for parameter '"); log.s(par); log.sn("'")
      ELSIF arg # "" THEN
        log.s("Dublicated parameter '"); log.s(par); log.sn("'")
      ELSIF ~CLI.Get(arg, ofs, ind) THEN
        log.s("Argument for parameter '"); log.s(par); log.sn("' too long")
      ELSE
        INC(ind);
        ok := TRUE
      END
    END
  RETURN
    match OR ~ok
  END Option;

  PROCEDURE BoolOption(VAR ind: INTEGER; par: ARRAY OF CHAR; val: INTEGER; VAR set: SET;
                       VAR ok: BOOLEAN): BOOLEAN;
  VAR match: BOOLEAN; buf: ARRAY 24 OF CHAR; ofs: INTEGER;
  BEGIN
    ofs := 0;
    match := (ind < CLI.count) & CLI.Get(buf, ofs, ind) & (buf = par);
    IF ~match THEN
      ;
    ELSIF val IN set THEN
      log.s("Dublicated parameter '"); log.s(par); log.sn("'");
      ok := FALSE
    ELSE
      INC(ind);
      INCL(set, val)
    END
  RETURN
    match OR ~ok
  END BoolOption;
BEGIN
  ok := TRUE;
  len := 0;
  IF (CLI.count = 0) OR ~CLI.Get(args[0], len, 0) THEN
    ok := FALSE;
    Help(TRUE)
  ELSIF args[0] = "help" THEN
    Help(TRUE)
  ELSIF args[0] = "version" THEN
    log.sn(Version)
  ELSIF args[0] = "text" THEN
    args[0] := "";
    args[1] := "";
    i := 1;
    argInd := 0;
    tabOpt := "";
    WHILE ok & (i < CLI.count) DO
      IF ~Option(i, "-commander-to", options.commanderReplacement, ok)
       & ~BoolOption(i, "-skip-embedded-view", Odc.SkipEmbeddedView, options.set, ok)
       & ~BoolOption(i, "-skip-comment", Odc.SkipOberonComment, options.set, ok)
       & ~Option(i, "-tab", tabOpt, ok)
       & (argInd < LEN(args))
      THEN
        len := 0;
        ASSERT(CLI.Get(args[argInd], len, i));
        INC(i);
        INC(argInd)
      END
    END;
    IF tabOpt # "" THEN
      ASSERT(Chars0X.Set(options.tab, tabOpt))
    END;
    IF ok & (i < CLI.count) THEN
      ok := FALSE;
      log.sn("Too many arguments for command 'text'")
    END;
    ok := ok & Text(args[0], args[1], options)
  ELSIF args[0] = "git" THEN
    IF CLI.count = 1 THEN
      ok := AddToGit("")
    ELSIF CLI.count = 2 THEN
      len := 0;
      ASSERT(CLI.Get(args[0], len, 1));
      len := Chars0X.Trim(args[0], 0);
      ok := AddToGit(args[0]);
    ELSE
      ok := FALSE;
      log.sn("Too many arguments for command 'git'")
    END
  ELSE
    ok := FALSE;
    log.s("Wrong command '"); log.s(args[0]); log.sn("'")
  END;
  CLI.SetExitCode(1 - ORD(ok))
END Cli;

BEGIN
  Odc.DefaultOptions(options);
END odcey.
