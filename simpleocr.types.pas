unit simpleocr.types;
{==============================================================================]
  Copyright (c) 2019, Jarl `slacky` Holta
  Project: SimpleOCR
  Project URL: https://github.com/slackydev/SimpleOCR
  License: GNU Lesser GPL (http://www.gnu.org/licenses/lgpl.html)
[==============================================================================}
{$mode objfpc}{$H+}
{$macro on}
{$inline on}
 
interface

type
  PParamArray = ^TParamArray;
  TParamArray = array[Word] of Pointer;
  
  PPoint = ^TPoint;
  TPoint = packed record X, Y: Int32; end;

  PPointArray = ^TPointArray;
  TPointArray = array of TPoint;

  PIntegerArray = ^TIntegerArray;
  TIntegerArray = array of Int32;

  P2DIntegerArray = ^T2DIntegerArray;
  T2DIntegerArray = array of TIntegerArray;

  PBox = ^TBox;
  TBox = packed record
    X1, Y1, X2, Y2: Int32;
  end;

  PRGB32 = ^TRGB32;
  TRGB32 = packed record 
    B, G, R, A: UInt8;
  end;

function Point(X, Y: Int32): TPoint;

implementation

function Point(X, Y: Int32): TPoint; inline;
begin
  Result.X := X;
  Result.Y := Y;
end;

end.
