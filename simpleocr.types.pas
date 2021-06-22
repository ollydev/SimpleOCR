unit simpleocr.types;
{==============================================================================]
  Copyright (c) 2021, Jarl `slacky` Holta
  Project: SimpleOCR
  Project URL: https://github.com/slackydev/SimpleOCR
  License: GNU Lesser GPL (http://www.gnu.org/licenses/lgpl.html)
[==============================================================================}
{$i simpleocr.inc}

interface

type
  PPoint = ^TPoint;
  TPoint = packed record
    X, Y: Int32;
  end;

  PBox = ^TBox;
  TBox = packed record
    X1, Y1, X2, Y2: Int32;
  end;

  PRGB32 = ^TRGB32;
  TRGB32 = packed record 
    B, G, R, A: UInt8;
  end;

  TRGB32Matrix = array of array of TRGB32;

  PPointArray = ^TPointArray;
  TPointArray = array of TPoint;

  PBoxArray = ^TBoxArray;
  TBoxArray = array of TBox;

  PIntegerArray = ^TIntegerArray;
  TIntegerArray = array of Int32;

  P2DIntegerArray = ^T2DIntegerArray;
  T2DIntegerArray = array of TIntegerArray;

  PStringArray = ^TStringArray;
  TStringArray = array of String;

function Point(const X, Y: Int32): TPoint; inline;
function Box(const X1, Y1, X2, Y2: Int32): TBox; inline;
function MatrixDimensions(const Matrix: T2DIntegerArray; out Width, Height: Int32): Boolean; inline;

implementation

function Point(const X, Y: Int32): TPoint;
begin
  Result.X := X;
  Result.Y := Y;
end;

function Box(const X1, Y1, X2, Y2: Int32): TBox;
begin
  Result.X1 := X1;
  Result.Y1 := Y1;
  Result.X2 := X2;
  Result.Y2 := Y2;
end;

function MatrixDimensions(const Matrix: T2DIntegerArray; out Width, Height: Int32): Boolean;
begin
  Result := True;

  Height := Length(Matrix);
  if (Height = 0) then
    Exit(False);
  Width := Length(Matrix[0]);
  if (Width = 0) then
    Exit(False);
end;

end.
