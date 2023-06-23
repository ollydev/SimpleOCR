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
    X, Y: Integer;
  end;

  PBox = ^TBox;
  TBox = packed record
    X1, Y1, X2, Y2: Integer;
  end;

  PRGB32 = ^TRGB32;
  TRGB32 = packed record 
    B, G, R, A: UInt8;
  end;

  PPointArray = ^TPointArray;
  TPointArray = array of TPoint;

  PBoxArray = ^TBoxArray;
  TBoxArray = array of TBox;

  PIntegerArray = ^TIntegerArray;
  TIntegerArray = array of Integer;

  PIntegerMatrix = ^TIntegerMatrix;
  TIntegerMatrix = array of TIntegerArray;

  PStringArray = ^TStringArray;
  TStringArray = array of String;

procedure Swap(var A, B: TPoint); inline;
procedure Swap(var A, B: Integer); inline;

function Point(const X, Y: Integer): TPoint; inline;
function Box(const X1, Y1, X2, Y2: Integer): TBox; inline;
function MatrixDimensions(const Matrix: TIntegerMatrix; out Width, Height: Integer): Boolean;

function TPABounds(const TPA: TPointArray): TBox;
function InvertTPA(const TPA: TPointArray): TPointArray;
procedure OffsetTPA(var TPA: TPointArray; SX, SY: Integer);
procedure InsSortTPA(var Arr :TPointArray; Weight: TIntegerArray; Left, Right: Integer);
procedure SortTPAbyColumn(var Arr: TPointArray);
function Mode(Self: TIntegerArray; Hi: Integer): Integer;

implementation

procedure Swap(var A, B: TPoint);
var
  C: TPoint;
begin
  C := A;
  A := B;
  B := C;
end;

procedure Swap(var A, B: Integer);
var
  C: Integer;
begin
  C := A;
  A := B;
  B := C;
end;

function Point(const X, Y: Integer): TPoint;
begin
  Result.X := X;
  Result.Y := Y;
end;

function Box(const X1, Y1, X2, Y2: Integer): TBox;
begin
  Result.X1 := X1;
  Result.Y1 := Y1;
  Result.X2 := X2;
  Result.Y2 := Y2;
end;

function MatrixDimensions(const Matrix: TIntegerMatrix; out Width, Height: Integer): Boolean;
begin
  Result := True;

  Height := Length(Matrix);
  if (Height = 0) then
    Exit(False);
  Width := Length(Matrix[0]);
  if (Width = 0) then
    Exit(False);
end;

//Return the largest and the smallest numbers for x, and y-axis in TPA.
function TPABounds(const TPA: TPointArray): TBox;
var
  I,L : Integer;
begin
  Result := Default(TBox);
  L := High(TPA);
  if (l < 0) then Exit;
  Result.x1 := TPA[0].x;
  Result.y1 := TPA[0].y;
  Result.x2 := TPA[0].x;
  Result.y2 := TPA[0].y;
  for I:= 1 to L do
  begin
    if TPA[i].x > Result.x2 then
      Result.x2 := TPA[i].x
    else if TPA[i].x < Result.x1 then
      Result.x1 := TPA[i].x;
    if TPA[i].y > Result.y2 then
      Result.y2 := TPA[i].y
    else if TPA[i].y < Result.y1 then
      Result.y1 := TPA[i].y;
  end;
end;

{*
 Returns the points not in the TPA within the area the TPA covers.
*}
function InvertTPA(const TPA: TPointArray): TPointArray;
var
  Matrix: TIntegerMatrix;
  i,h,x,y: Integer;
  Area: TBox;
begin
  Area := TPABounds(TPA);
  Area.X2 := (Area.X2-Area.X1);
  Area.Y2 := (Area.Y2-Area.Y1);
  SetLength(Matrix, Area.Y2+1, Area.X2+1);

  H := High(TPA);
  for i:=0 to H do
    Matrix[TPA[i].y-Area.y1][TPA[i].x-Area.x1] := 1;

  SetLength(Result, (Area.X2+1)*(Area.Y2+1) - H);
  i := 0;
  for y:=0 to Area.Y2 do
    for x:=0 to Area.X2 do
      if Matrix[y][x] <> 1 then
      begin
        Result[i].X := x+Area.x1;
        Result[i].Y := y+Area.y1;
        Inc(i);
      end;
  SetLength(Result, i);
  SetLength(Matrix, 0);
end;

{*
 Moves the TPA by SX, and SY points.
*}
procedure OffsetTPA(var TPA: TPointArray; SX, SY: Integer);
var
  I: Integer;
begin
  for I := 0 to High(TPA) do
  begin
    TPA[I].X := TPA[I].X + SX;
    TPA[I].Y := TPA[I].Y + SY;
  end;
end;

//Fast TPointArray sorting for small arrays.
procedure InsSortTPA(var Arr: TPointArray; Weight: TIntegerArray; Left, Right: Integer);
var
  i, j: Integer;
begin
  for i := Left to Right do
    for j := i downto Left + 1 do
    begin
      if not (Weight[j] < Weight[j - 1]) then
        Break;

      Swap(Arr[j-1], Arr[j]);
      Swap(Weight[j-1], Weight[j]);
    end;
end;

//Sort small TPA by Column.
procedure SortTPAbyColumn(var Arr: TPointArray);
var
  i,Hi: Integer;
  Weight: TIntegerArray;
  Area : TBox;
begin
  Hi := High(Arr);
  if Hi < 0 then Exit;
  Area := TPABounds(Arr);
  SetLength(Weight, Hi+1);
  for i := 0 to Hi do
    Weight[i] := (Arr[i].x * (Area.Y2-Area.Y1) + Arr[i].y);
  InsSortTPA(Arr, Weight, 0, Hi);
  SetLength(Weight, 0);
end;

procedure QuickSort(var A: TIntegerArray; iLo, iHi: Integer);
var
  Lo, Hi, Pivot, T: Integer;
begin
  Lo := iLo;
  Hi := iHi;
  Pivot := A[(Lo + Hi) div 2];
  repeat
    while A[Lo] < Pivot do Inc(Lo);
    while A[Hi] > Pivot do Dec(Hi);
    if Lo <= Hi then
    begin
      T := A[Lo];
      A[Lo] := A[Hi];
      A[Hi] := T;
      Inc(Lo);
      Dec(Hi);
    end;
  until Lo > Hi;
  if Hi > iLo then QuickSort(A, iLo, Hi);
  if Lo < iHi then QuickSort(A, Lo, iHi);
end;

function Mode(Self: TIntegerArray; Hi: Integer): Integer;
var
  I, Hits, Best: Integer;
  Cur: Integer;
begin
  Result := 0;

  if (Length(Self) > 0) then
  begin
    QuickSort(Self, 0, Hi);

    Cur := Self[0];
    Hits := 1;
    Best := 0;

    for I := 1 to Hi do
    begin
      if (Self[I] <> Cur) then
      begin
        if (Hits > Best) then
        begin
          Best := Hits;
          Result := Cur;
        end;

        Hits := 0;
        Cur := Self[I];
      end;

      Inc(Hits);
    end;

    if (Hits > Best) then
      Result := Cur;
  end;
end;

end.
