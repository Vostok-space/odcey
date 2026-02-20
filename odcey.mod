#!/usr/bin/env -S ost .

Copyright 2022-2026 ComdivByZero

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
  CFiles,
  Stream := VDataStream,
  File := VFileStream,
  Copy := VCopy,
  VDefaultIO,
  OsEnv, OsExec,
  Charz,
  Utf8, Windows1251 := OldCharsetWindows1251,
  Platform;

CONST
  Version* = "0.4";

  McConfig = ".config/mc/mc.ext.ini";
  McConfigBackup = ".config/mc/mc.ext.ini~";
  McConfigNew = ".config/odcey-new-mc.ext.ini";

VAR
  options: Odc.Options;

PROCEDURE Help(cli: BOOLEAN);
VAR commanderTo, skipEmbedded, skipComment, tab, windows1251: ARRAY 42 OF CHAR;
BEGIN
  log.sn("odcey - converter of .odc format to plain text");
  log.n;
  log.sn("Usage:");
  IF cli THEN
    log.sn(" 0. odcey text  [input [output]] { options }");
    log.sn("    odcey [text] input [output]  { options }");
    log.sn(" 1. odcey git    [dir]");
    log.sn(" 2. odcey mc");
    commanderTo  := "-commander-to <str>";
    skipEmbedded := "-skip-embedded-view";
    skipComment  := "-skip-comment      ";
    windows1251  := "-input-windows1251 ";
    tab          := "-tab <str>         "
  ELSE
    log.sn(" 0. odcey.text(input, output)");
    log.sn(" 1. odcey.addToGit(dir)");
    commanderTo  := "odcey.commanderTo(str)            ";
    skipEmbedded := "odcey.opt({Odc.SkipEmbeddedView })";
    skipComment  := "          {Odc.SkipOberonComment} ";
    windows1251  := "          {Odc.InputWindows1251}  ";
    tab          := "odcey.tab(str)                    "
  END;
  log.n;
  log.sn("0. Print text content of .odc, empty arguments for standard IO");
  log.s("   "); log.s(commanderTo); log.sn("  set Commander-view replacement");
  log.s("   "); log.s(skipEmbedded); log.sn("  skips embedded views writing");
  log.s("   "); log.s(skipComment); log.sn("  skips (* Oberon comments *) ");
  log.s("   "); log.s(windows1251); log.sn("  set charset Windows-1251 instead of Latin-1");
  log.s("   "); log.sn("  (useful for legacy Cyrillic BlackBox builds)");
  log.s("   "); log.s(tab); log.sn("  set tabulation replacement");
  log.n;
  log.sn("1. Embed to a .git repo as a text converter; empty argument for current dir");
  log.sn("2. Configure viewer of midnight commander")
END Help;

PROCEDURE Text(input, output: ARRAY OF CHAR; opts: Odc.Options): BOOLEAN;
VAR ok: BOOLEAN; in: Stream.PIn; out: Stream.POut; doc: Odc.Document; opt: Odc.Options;
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
      opt := opts;
      IF output = "" THEN
        out := VDefaultIO.OpenOut();
        opt.lastNewLine := TRUE
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
    OR  Charz.CopyString(res, len, dir)
      & Charz.PutChar(res, len, "/")
   )
 & Charz.CopyString(res, len, file)
END ConcatPath;

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

PROCEDURE OpenIn(dir, file: ARRAY OF CHAR): File.In;
VAR path: ARRAY 4096 OF CHAR; in: File.In;
BEGIN
  IF ConcatPath(path, dir, file) THEN
    in := File.OpenIn(path)
  ELSE
    in := NIL
  END;
  IF in = NIL THEN
    log.s("Can not open '");
    log.s(path);
    log.sn("'")
  END
RETURN
  in
END OpenIn;

PROCEDURE AddToGit(gitDir: ARRAY OF CHAR): BOOLEAN;
VAR ok: BOOLEAN; attrs, config: File.Out; str: ARRAY 64 OF CHAR; len: INTEGER;
BEGIN
  attrs  := Open(gitDir, ".git/info/attributes");
  config := Open(gitDir, ".git/config");
  ok := (attrs # NIL) & (config # NIL);
  IF ok THEN
    len := 0;
    ASSERT(Charz.PutChar   (str, len, Utf8.NewLine)
         & Charz.CopyString(str, len, "*.odc diff=cp")
         & Charz.PutChar   (str, len, Utf8.NewLine));
    ok := len = Stream.WriteChars(attrs^, str, 0, len);
    IF ~ok THEN
      log.sn("Can not edit .git/info/attributes")
    ELSE
      ok := (OsExec.Do("git config diff.cp.binary true") = 0)
          & (OsExec.Do("git config diff.cp.textconv 'odcey text <'") = 0);
      IF ~ok THEN
        log.sn("Can not setup git textconv")
      END
    END
  END;
  File.CloseOut(attrs);
  File.CloseOut(config);
RETURN
  ok
END AddToGit;

PROCEDURE Rename(dir, name, newName: ARRAY OF CHAR): BOOLEAN;
VAR old, new: ARRAY 1000H OF CHAR;
RETURN
  ConcatPath(old, dir, name)
& ConcatPath(new, dir, newName)
& CFiles.Rename(old, 0, new, 0)
END Rename;

PROCEDURE AddToMc(): BOOLEAN;
VAR ok, oldOk: BOOLEAN; config: File.Out; old: File.In; home, str: ARRAY 100H OF CHAR; len: INTEGER;
BEGIN
  len := 0;
  ok := OsEnv.Get(home, len, "HOME");
  IF ok THEN
    config := Open(home, McConfigNew);
    old := OpenIn(home, McConfig);
    oldOk := old # NIL;
    ok := (config # NIL);
    IF ok THEN
      len := 0;
      ASSERT(Charz.CopyString(str, len, "#odc BlackBox Component Builder container document")
           & Charz.PutChar   (str, len, Utf8.NewLine)
           & Charz.CopyString(str, len, "[odc]")
           & Charz.PutChar   (str, len, Utf8.NewLine)
           & Charz.CopyString(str, len, "Shell=.odc")
           & Charz.PutChar   (str, len, Utf8.NewLine)
           & Charz.CopyString(str, len, "View=%view{ascii} odcey text %f")
           & Charz.PutChar   (str, len, Utf8.NewLine)
           & Charz.PutChar   (str, len, Utf8.NewLine));
      ok := (len = Stream.WriteChars(config^, str, 0, len));
      IF ok & oldOk THEN
        Copy.UntilEnd(old^, config^) (* TODO *)
      END
    END;
    File.CloseIn(old);
    File.CloseOut(config);
    IF ok THEN
      ok := (~oldOk OR Rename(home, McConfig, McConfigBackup))
          & Rename(home, McConfigNew, McConfig)
    END
  END
RETURN
  ok
END AddToMc;

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

PROCEDURE addToMc*;
BEGIN
  IF ~AddToMc() THEN
    log.s("Can not edit "); log.sn(McConfig)
  END
END addToMc;

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
  i := 0;
  IF (CLI.count = 0) OR ~CLI.Get(args[0], len, 0) THEN
    ok := FALSE;
    Help(TRUE)
  ELSIF args[0] = "help" THEN
    Help(TRUE)
  ELSIF args[0] = "version" THEN
    log.sn(Version)
  ELSIF (args[0] = "text") OR (Charz.SearchChar(args[0], i, ".")) THEN
    i := ORD(args[0] = "text");
    IF i = 1 THEN
      args[0] := ""
    END;
    args[1] := "";
    argInd := 0;
    tabOpt := "";
    WHILE ok & (i < CLI.count) DO
      IF ~Option(i, "-commander-to", options.commanderReplacement, ok)
       & ~BoolOption(i, "-skip-embedded-view", Odc.SkipEmbeddedView, options.set, ok)
       & ~BoolOption(i, "-skip-comment", Odc.SkipOberonComment, options.set, ok)
       & ~BoolOption(i, "-input-windows1251", Odc.InputWindows1251, options.set, ok)
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
      ASSERT(Charz.Set(options.tab, tabOpt))
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
      len := Charz.Trim(args[0], 0);
      ok := AddToGit(args[0])
    ELSE
      ok := FALSE;
      log.sn("Too many arguments for command 'git'")
    END
  ELSIF args[0] = "mc" THEN
    ok := AddToMc()
  ELSE
    ok := FALSE;
    log.s("Wrong command '"); log.s(args[0]); log.sn("'")
  END;
  CLI.SetExitCode(1 - ORD(ok))
END Cli;

BEGIN
  Odc.DefaultOptions(options);
END odcey.
