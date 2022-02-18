Oberon Document Container rough support
Used as sample:
 * BlackBox/Dev/Specs/StoresFileFormat
 * BlackBox/System/Mod/Stores
 * BlackBox/Text/Mod/Models
 * BlackBox/Docu/BB-Chars
 * odcread source

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

MODULE Odc;

IMPORT
  Stream := VDataStream,
  Read := VStreamRead,
  VDefaultIO,
  File := VFileStream,
  log,
  CLI,
  Chars0X,
  TypesLimits,
  Utf8;

CONST
  Version* = "0.d.0";

  Nil*     = 80H;
  Link*    = 81H;
  Store*   = 82H;
  Elem*    = 83H;
  NewLink* = 84H;

  Data*    = 100H;(* Специальный идентификатор неинтерпретируемых данных *)

  NewBase* = 0F0H;
  NewExt*  = 0F1H;
  OldType* = 0F2H;

  FormatTag* = "CDOo";

  TypeNameLen = 63;

  BlockSize = 4096;

  PieceView  = 0;
  PieceChar1 = 1;
  PieceChar2 = 2;

  BlackboxReplacementMin = 8BX;
  SpaceZeroWidth    = 8BX;
  DigitSpace        = 8FX;
  Hyphen            = 90X;
  NonBreakingHyphen = 91X;
  BlackboxReplacementMax = 91X;

  CodeSpaceZeroWidth    = 200BH;
  CodeHyphen            = 2010H;
  CodeNonBreakingHyphen = 2011H;

TYPE
  Types = RECORD
    desc: ARRAY 128 OF RECORD
      name: INTEGER;
      base: INTEGER
    END;
    names: ARRAY 4096 OF CHAR;
    top, currentDesc,
    stdModel: INTEGER
  END;

  PBlock = POINTER TO Block;
  Block = RECORD
    data: ARRAY BlockSize - 32 OF CHAR;
    used: INTEGER;
    next: PBlock
  END;

  PPiece = POINTER TO Piece;
  Piece = RECORD
    block: PBlock;
    ofs,
    size: INTEGER;

    next: PPiece;

    kind: BYTE
  END;

  PObject = POINTER TO Object;
  PStruct = POINTER TO Struct;
  Struct = RECORD
    kind: INTEGER;

    data: PPiece;
    object: PObject;

    next: PStruct
  END;

  Object = RECORD
    type: INTEGER;
    first, last: PStruct
  END;

  Text = POINTER TO RECORD(Object)
    pieces: PPiece
  END;

  Document* = POINTER TO RECORD
    types: Types;

    struct: Struct
  END;

VAR
  readStruct: PROCEDURE(VAR in: Stream.In; VAR types: Types; VAR block: PBlock;
                        VAR next, size: INTEGER; rest: INTEGER;
                        VAR struct: Struct): BOOLEAN;

PROCEDURE TypesInit(VAR t: Types);
BEGIN
  t.top := 0;
  t.stdModel := -1;
  t.desc[0].name := 0;
  t.names := ""
END TypesInit;

PROCEDURE BlockNew(VAR b: PBlock): BOOLEAN;
BEGIN
  NEW(b);
  IF b # NIL THEN
    b.used := 0;
    b.next := NIL
  END
RETURN
  b # NIL
END BlockNew;

PROCEDURE PieceNew(VAR b: PBlock; size: INTEGER; charSize: INTEGER; VAR p: PPiece): BOOLEAN;
VAR ok: BOOLEAN;
BEGIN
  ASSERT(size > 0);
  ASSERT(charSize IN {PieceChar1, PieceChar2});

  NEW(p);
  ok := (p # NIL)
      & ((b # NIL) OR BlockNew(b));
  IF ok THEN
    p.kind := charSize;
    p.size := size;
    p.block := b;
    p.ofs := b.used;

    IF size >= LEN(b.data) - b.used THEN
      b.used := LEN(b.data)
    ELSE
      INC(b.used, (LEN(b.data) - b.used))
    END;
    DEC(size, LEN(b.data) - b.used);

    WHILE ok & (size >= LEN(b.data)) DO
      ok := BlockNew(b.next);
      IF ok THEN
        b := b.next;
        b.used := LEN(b.data);
        DEC(size, LEN(b.data))
      END
    END;

    IF ok & (size > 0) THEN
      ok := BlockNew(b.next);
      IF ok THEN
        b := b.next;
        b.used := size
      END
    END;

    INC(b.used, b.used MOD 2);
    IF b.used = LEN(b.data) THEN
      b := NIL
    END
  END;
  IF ~ok THEN
    p := NIL
  END
RETURN
  ok
END PieceNew;

PROCEDURE PieceViewNew(VAR p: PPiece): BOOLEAN;
BEGIN
  NEW(p);
  IF p # NIL THEN
    p.size  := -1;
    p.block := NIL;
    p.ofs   := -1;
    p.next  := NIL;
    p.kind := PieceView
  END
RETURN
  p # NIL
END PieceViewNew;

PROCEDURE ReadIntro(VAR in: Stream.In): BOOLEAN;
VAR version: INTEGER;
RETURN
  Read.SameChars(in, FormatTag, 0, LEN(FormatTag) - 1)
& Read.LeUinteger(in, version) & (version = 0)
END ReadIntro;

PROCEDURE ReadNext(VAR in: Stream.In; VAR comment, next: INTEGER): BOOLEAN;
RETURN
  Read.LeUinteger(in, comment)
& Read.LeUinteger(in, next)
END ReadNext;

PROCEDURE ReadEndNext(VAR in: Stream.In; VAR next: INTEGER): BOOLEAN;
VAR ok: BOOLEAN; comment: INTEGER;
BEGIN
  ok := ReadNext(in, comment, next) & (next = 0);
  IF ok & ~ODD(comment) THEN
    next := -1
  END
RETURN
  ok
END ReadEndNext;

PROCEDURE ReadMidNext(VAR in: Stream.In; VAR next: INTEGER): BOOLEAN;
VAR comment: INTEGER;
RETURN
  ReadNext(in, comment, next)
& ((next > 0) OR ~ODD(comment))
END ReadMidNext;

PROCEDURE ReadPath(VAR in: Stream.In; VAR types: Types; VAR size: INTEGER; rest: INTEGER): BOOLEAN;
VAR id: BYTE; ok: BOOLEAN; tid, prev, s: INTEGER;
  PROCEDURE SetBase(VAR types: Types; prev, id: INTEGER);
  BEGIN
    IF prev >= 0 THEN
      types.desc[prev].base := id
    ELSE
      types.currentDesc := id
    END
  END SetBase;
BEGIN
  prev := -1;
  ok := Read.Byte(in, id);
  s := 1;
  WHILE ok & (id = NewExt) DO
    SetBase(types, prev, types.top);
    prev := types.top; INC(types.top);
    types.desc[types.top].name := types.desc[prev].name;
    ok := (types.desc[types.top].name < LEN(types.names) - TypeNameLen - 2)
        & (Read.UntilChar(in, 0X, TypeNameLen + 1, types.names, types.desc[types.top].name) = 0X)
        & Read.Byte(in, id);
    INC(s, 1 + types.desc[types.top].name - types.desc[prev].name)
  END;
  tid := -1;
  IF ~ok THEN
    ;
  ELSIF id = NewBase THEN
    SetBase(types, prev, types.top);
    INC(types.top);
    types.desc[types.top].name := types.desc[types.top - 1].name;
    ok := Read.UntilChar(in, 0X, TypeNameLen + 1, types.names, types.desc[types.top].name) = 0X;
    INC(s, types.desc[types.top].name - types.desc[types.top - 1].name)
  ELSE
    ok := (id = OldType) & Read.LeUinteger(in, tid) & (tid < types.top);
    INC(s, 4);
    SetBase(types, prev, tid)
  END;
  size := s;

  IF ok & (types.stdModel < 0)
   & (0 = Chars0X.Compare(types.names, types.desc[types.currentDesc].name, "TextModels.StdModelDesc", 0))
  THEN
    types.stdModel := types.currentDesc
  END
RETURN
  ok
END ReadPath;

PROCEDURE ReadNil(VAR in: Stream.In; VAR n: INTEGER): BOOLEAN;
RETURN
  ReadEndNext(in, n)
END ReadNil;

PROCEDURE ReadLink(VAR in: Stream.In; new: BOOLEAN; VAR n: INTEGER): BOOLEAN;
VAR lid: INTEGER;
RETURN
  Read.LeUinteger(in, lid)
& ReadEndNext(in, n)
END ReadLink;

PROCEDURE ReadView(VAR in: Stream.In; VAR types: Types; VAR block: PBlock;
                   VAR next, size: INTEGER; rest: INTEGER;
                   VAR obj: PObject): BOOLEAN;
VAR width, height: INTEGER; ok: BOOLEAN; struct: Struct;
BEGIN
  size := 0;
  ok := (rest > 0)
      & Read.LeUinteger(in, width)
      & Read.LeUinteger(in, height)
      & readStruct(in, types, block, next, size, rest, struct);
  IF ok THEN
    INC(size, 8);
    obj := struct.object
  END
RETURN
  ok
END ReadView;

PROCEDURE ReadPieces(VAR in: Stream.In; p: PPiece): BOOLEAN;
VAR ok: BOOLEAN; ofs, size: INTEGER; b: PBlock; viewId: BYTE;
BEGIN
  REPEAT
    b := p.block;
    size := p.size;
    IF size <= 0 THEN
      ok := Read.Byte(in, viewId)
    ELSE
      ofs := p.ofs;
      IF size <= LEN(b.data) - ofs THEN
        ok := size = Stream.ReadChars(in, b.data, ofs, size)
      ELSE
        ok := LEN(b.data) - ofs = Stream.ReadChars(in, b.data, ofs, LEN(b.data) - ofs);
        DEC(size, LEN(b.data) - ofs);
        WHILE ok & (size > LEN(b.data)) DO
          DEC(size, LEN(b.data));
          b := b.next;
          ok := LEN(b.data) = Stream.ReadCharsWhole(in, b.data)
        END;
        b := b.next;
        ok := ok & (size = Stream.ReadChars(in, b.data, 0, size))
      END
    END;
    p := p.next
  UNTIL (p = NIL) OR ~ok
RETURN
  ok
END ReadPieces;

PROCEDURE ObjInit(VAR obj: Object; type: INTEGER);
BEGIN
  ASSERT(type >= 0);

  obj.type := type;
  obj.first := NIL;
  obj.last := NIL
END ObjInit;

PROCEDURE ObjNew(VAR obj: PObject; type: INTEGER): BOOLEAN;
BEGIN
  NEW(obj);
  IF obj # NIL THEN
    ObjInit(obj^, type)
  END
RETURN
  obj # NIL
END ObjNew;

PROCEDURE TextNew(VAR obj: Text; types: Types): BOOLEAN;
BEGIN
  NEW(obj);
  IF obj # NIL THEN
    ObjInit(obj^, types.stdModel)
  END
RETURN
  obj # NIL
END TextNew;

PROCEDURE ReadStdModel(VAR in: Stream.In; VAR types: Types; VAR block: PBlock;
                       rest: INTEGER; VAR obj: PObject): BOOLEAN;
VAR ok: BOOLEAN; metaSize: INTEGER; txt: Text;

  PROCEDURE ReadMeta(VAR in: Stream.In; VAR types: Types; VAR block: PBlock;
                     VAR ps: PPiece;
                     metaSize, rest: INTEGER): BOOLEAN;
  CONST AttrEnd = 0FFH;
  VAR ok: BOOLEAN; last, curr: PPiece;
      textLen, attrTop, next, size: INTEGER; attrNum: BYTE; struct: Struct;
  BEGIN
    last := NIL;

    attrTop := 0;

    ok := Read.Byte(in, attrNum) & ((attrNum < 80H) OR (attrNum = AttrEnd));
    WHILE ok & (attrNum <= attrTop) DO
      DEC(metaSize, 5);
      IF attrNum = attrTop THEN
        ok := readStruct(in, types, block, next, size, metaSize, struct);
        DEC(metaSize, size);
        INC(attrTop)
      END;
      ok := ok & (metaSize > 0) & Read.LeInteger(in, textLen);
      IF ~ok THEN
        ;
      ELSIF textLen = 0 THEN
        DEC(rest);
        ok := (rest >= 0)
            & PieceViewNew(curr)
            & ReadView(in, types, block, next, size, metaSize, struct.object);
        DEC(metaSize, size)
      ELSE
        DEC(rest, ABS(textLen));
        ok := (rest >= 0)
            & PieceNew(block, ABS(textLen), PieceChar1 + ORD(textLen < 0), curr)
      END;
      IF ~ok THEN
        ;
      ELSIF last # NIL THEN
        last.next := curr
      ELSE
        ps := curr
      END;
      last := curr;
      ok := ok & Read.Byte(in, attrNum)
    END;
    ok := ok & (attrNum = AttrEnd) & (metaSize = 1) & (rest = 0)
  RETURN
    ok
  END ReadMeta;
BEGIN
  DEC(rest, 10);
  txt := NIL;
  ok := (rest > 0)
      & TextNew(txt, types)

      & Read.Skip(in, 6)
      & Read.LeUinteger(in, metaSize) & (metaSize < rest)

      & ReadMeta(in, types, block, txt.pieces, metaSize, rest - metaSize)
      & ReadPieces(in, txt.pieces);
  obj := txt
RETURN
  ok
END ReadStdModel;

PROCEDURE ReadData(VAR in: Stream.In; VAR block: PBlock; size: INTEGER; VAR struct: PStruct): BOOLEAN;
VAR ok: BOOLEAN;
BEGIN
  NEW(struct);
  ok := (struct # NIL)
      & PieceNew(block, size, PieceChar1, struct.data)
      & ReadPieces(in, struct.data);
  IF ok THEN
    struct.kind := Data;
    struct.object := NIL
  END
RETURN
  ok
END ReadData;

PROCEDURE ReadAny(VAR in: Stream.In; VAR types: Types; VAR block: PBlock;
                  begin, rest: INTEGER;
                  VAR obj: PObject): BOOLEAN;
VAR ok: BOOLEAN;

  PROCEDURE ReadItem(VAR in: Stream.In; VAR types: Types; VAR block: PBlock;
                     VAR begin, rest: INTEGER;
                     VAR struct: PStruct): BOOLEAN;
  VAR ok: BOOLEAN; size: INTEGER;
  BEGIN
    NEW(struct);
    DEC(rest, begin);
    size := 0;
    ok := (struct # NIL)
        & (   (begin = 0)
           OR PieceNew(block, begin, PieceChar1, struct.data)
            & ReadPieces(in, struct.data)
          )
        & readStruct(in, types, block, begin, size, rest, struct^);
    DEC(rest, size)
  RETURN
    ok
  END ReadItem;
BEGIN
  ok := ObjNew(obj, types.currentDesc);
  IF ~ok THEN
    ;
  ELSIF begin >= 0 THEN
    ok := ReadItem(in, types, block, begin, rest, obj.first);
    obj.last := obj.first;
    WHILE ok & (begin >= 0) DO
      ok := ReadItem(in, types, block, begin, rest, obj.last.next);
      obj.last := obj.last.next
    END;
    IF ok & (rest > 0) THEN
      ok := ReadData(in, block, rest, obj.last.next);
      IF ok THEN
        obj.last := obj.last.next;
        obj.last.next := NIL
      END
    END
  ELSE
    ok := ReadData(in, block, rest, obj.first);
    IF ok THEN
      obj.last := obj.first;
      obj.last.next := NIL
    END
  END
RETURN
  ok
END ReadAny;

PROCEDURE ReadObject(VAR in: Stream.In; VAR types: Types; VAR block: PBlock;
                     VAR next, size: INTEGER; rest: INTEGER;
                     VAR obj: PObject): BOOLEAN;
VAR ok: BOOLEAN; pathSize, begin, content: INTEGER;
BEGIN
  ok := ReadPath(in, types, pathSize, rest)
      & (16 <= (rest - pathSize))

      & ReadMidNext(in, next)

      & Read.LeUinteger(in, begin)
      & ((begin = 0) OR (begin >= 4))

      & Read.LeUinteger(in, content)
      & ((next = 0) OR (next >= 8) & (content <= next - 8))
      & (content > begin - 4) & (content <= rest - 16 - pathSize);
  IF ~ok THEN
    size := 0
  ELSE
    size := pathSize + content + 16;
    next := next - 8 - content;

    IF types.currentDesc = types.stdModel THEN
      ok := ReadStdModel(in, types, block, content, obj)
    ELSE
      ok := ReadAny(in, types, block, begin - 4, content, obj)
    END
  END
RETURN
  ok
END ReadObject;

PROCEDURE ReadStruct(VAR in: Stream.In; VAR types: Types; VAR block: PBlock;
                     VAR next, size: INTEGER; rest: INTEGER;
                     VAR struct: Struct): BOOLEAN;
VAR id: BYTE; ok: BOOLEAN;
BEGIN
  ok := (rest > 0) & Read.Byte(in, id);
  IF ~ok THEN
    size := 0
  ELSE
    struct.data   := NIL;
    struct.object := NIL;
    struct.kind   := id;
    IF id = Nil THEN
      size := 9;
      ok := (rest >= size) & ReadNil(in, next);
    ELSIF (id = Link) OR (id = NewLink) THEN
      size := 13;
      ok := (rest >= size) & ReadLink(in, id = NewLink, next)
    ELSIF (id = Elem) OR (id = Store) THEN
      ok := ReadObject(in, types, block, next, size, rest - 1, struct.object);
      INC(size)
    ELSE
      size := 1;
      ok := FALSE
    END
  END
RETURN
  ok
END ReadStruct;

PROCEDURE ReadDoc*(VAR in: Stream.In; VAR doc: Document): BOOLEAN;
VAR next, size: INTEGER; block: PBlock;
BEGIN
  NEW(doc);
  IF doc # NIL THEN
    TypesInit(doc.types);
    block := NIL;
    IF ~(ReadIntro(in)
       & ReadStruct(in, doc.types, block, next, size, TypesLimits.IntegerMax, doc.struct)
       & (next < 0)
        )
    THEN
      doc := NIL
    END
  END
RETURN
  doc # NIL
END ReadDoc;

PROCEDURE Code*(char: CHAR): INTEGER;
VAR code: INTEGER;
BEGIN
  IF Utf8.CarRet = char THEN
    code := ORD(Utf8.NewLine)
  ELSIF (BlackboxReplacementMin > char) OR (char < BlackboxReplacementMax) THEN
    code := ORD(char)
  ELSIF SpaceZeroWidth = char THEN
    code := CodeSpaceZeroWidth
  ELSIF DigitSpace = char THEN
    code := ORD(Utf8.Space)
  ELSIF Hyphen = char THEN
    code := CodeHyphen
  ELSIF NonBreakingHyphen = char THEN
    code := CodeNonBreakingHyphen
  ELSE
    code := ORD(char)
  END
RETURN
  code
END Code;

PROCEDURE WritePiece(VAR out: Stream.Out; p: Piece): BOOLEAN;
VAR ofs, size, len, charSize, code: INTEGER; b: PBlock; ok: BOOLEAN; utf8: ARRAY 4 OF CHAR;
BEGIN
  charSize := p.kind;
  b := p.block;
  size := p.size;
  ofs := p.ofs;
  REPEAT
    len := 0;

    IF charSize = 1 THEN
      code := Code(b.data[ofs])
    ELSE
      code := ORD(b.data[ofs]) + ORD(b.data[ofs + 1]) MOD 80H * 100H
    END;
    DEC(size, charSize);
    INC(ofs, charSize);
    IF ofs = LEN(b.data) THEN
      ofs := 0;
      b := b.next
    END;
    ASSERT(Utf8.FromCode(utf8, len, code));
    ok := len = Stream.WriteChars(out, utf8, 0, len)
  UNTIL ~ok OR (size = 0)
RETURN
  ok
END WritePiece;

PROCEDURE WritePieces(VAR out: Stream.Out; ps: PPiece): BOOLEAN;
BEGIN
  WHILE (ps # NIL)
      & ((ps.kind = PieceView) OR WritePiece(out, ps^))
  DO
    ps := ps.next
  END
RETURN
  ps = NIL
END WritePieces;

PROCEDURE WriteObject(VAR out: Stream.Out; types: Types; obj: PObject): BOOLEAN;
VAR ok: BOOLEAN; struct: PStruct;
BEGIN
  IF obj.type = types.stdModel THEN
    ok := WritePieces(out, obj(Text).pieces)
  ELSIF obj.first # NIL THEN
    struct := obj.first;
    REPEAT
      ok := (struct.object = NIL) OR WriteObject(out, types, struct.object);
      struct := struct.next
    UNTIL ~ok OR (struct = NIL)
  ELSE
    ok := TRUE
  END
RETURN
  ok
END WriteObject;

PROCEDURE PrintDoc*(VAR out: Stream.Out; doc: Document): BOOLEAN;
RETURN
  (doc.struct.object = NIL) OR WriteObject(out, doc.types, doc.struct.object)
END PrintDoc;

BEGIN
  readStruct := ReadStruct
END Odc.
