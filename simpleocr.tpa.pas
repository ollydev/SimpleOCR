unit simpleocr.tpa;
{==============================================================================]
  Copyright (c) 2021, Jarl `slacky` Holta
  Project: SimpleOCR
  Project URL: https://github.com/slackydev/SimpleOCR
  License: GNU Lesser GPL (http://www.gnu.org/licenses/lgpl.html)
[==============================================================================}
{$mode objfpc}{$H+}
{$macro on}

interface

uses
  simpleocr.types;

procedure Exch(var A,B:UInt8); Inline; overload;
procedure Exch(var A,B:Int32); Inline; overload;
procedure Exch(var A,B:TPoint); Inline; overload;

function TPABounds(const TPA: TPointArray): TBox;
function CombineTPA(const TPA1, TPA2: TPointArray): TPointArray;
function InvertTPA(const TPA: TPointArray): TPointArray;
procedure OffsetTPA(var TPA: TPointArray; SX,SY:Integer);
procedure InsSortTPA(var Arr :TPointArray; Weight: TIntegerArray; Left, Right:Int32);
procedure SortTPAbyColumn(var Arr: TPointArray);
function Mode(Self: TIntegerArray): Int32;

implementation 

procedure Exch(var A,B:UInt8);
var t:UInt8;
begin 
  t := A; A := B; B := t; 
end;

procedure Exch(var A,B:Int32);
var t:Int32;
begin 
  t := A; A := B; B := t; 
end;

procedure Exch(var A,B:TPoint);
var t:TPoint;
begin 
  t := A; A := B; B := t; 
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
 Unite two TPAs into one
*}
function CombineTPA(const TPA1, TPA2: TPointArray): TPointArray;
begin
  if (High(TPA1) = -1) then Exit(TPA2)
  else if (High(TPA2) = -1) then Exit(TPA1);
  SetLength(Result, High(TPA1) + High(TPA2) + 2);
  Move(TPA1[Low(TPA1)], Result[Low(Result)],  Length(TPA1)*SizeOf(TPA1[0]));
  Move(TPA2[Low(TPA2)], Result[Length(TPA1)], Length(TPA2)*SizeOf(TPA2[0]));
end; 

{*
 Returns the points not in the TPA within the area the TPA covers.
*}
function InvertTPA(const TPA: TPointArray): TPointArray;
var
  Matrix: T2DIntegerArray;
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
procedure OffsetTPA(var TPA: TPointArray; SX,SY:Integer);
var
  I,L : Integer;
begin;
  L := High(TPA);
  if (L < 0) then Exit;
  for I:=0 to L do begin
    TPA[i].x := TPA[i].x + SX;
    TPA[i].y := TPA[i].y + SY;
  end;
end;

//Fast TPointArray sorting for small arrays.
procedure InsSortTPA(var Arr: TPointArray; Weight: TIntegerArray; Left, Right: Int32);
var i, j:Int32;
begin
  for i := Left to Right do
    for j := i downto Left + 1 do begin
      if not (Weight[j] < Weight[j - 1]) then Break;
      Exch(Arr[j-1], Arr[j]);
      Exch(Weight[j-1], Weight[j]);
    end;
end;

//Sort small TPA by Column.
procedure SortTPAbyColumn(var Arr: TPointArray);
var
  i,Hi: Int32;
  Weight:TIntegerArray;
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

procedure QuickSort(var A: TIntegerArray; iLo, iHi: Integer) ;
var
  Lo, Hi, Pivot, T: Integer;
begin
  Lo := iLo;
  Hi := iHi;
  Pivot := A[(Lo + Hi) div 2];
  repeat
    while A[Lo] < Pivot do Inc(Lo) ;
    while A[Hi] > Pivot do Dec(Hi) ;
    if Lo <= Hi then
    begin
      T := A[Lo];
      A[Lo] := A[Hi];
      A[Hi] := T;
      Inc(Lo) ;
      Dec(Hi) ;
    end;
  until Lo > Hi;
  if Hi > iLo then QuickSort(A, iLo, Hi) ;
  if Lo < iHi then QuickSort(A, Lo, iHi) ;
end;

function Mode(Self: TIntegerArray): Int32;
var
  i,hits,best: Int32;
  cur: Int32;
begin
  Result := 0;

  if Length(Self) > 0 then
  begin
    QuickSort(Self, Low(Self), High(Self));
    cur := self[0];
    hits := 1;
    best := 0;
    for i:=1 to High(self) do
    begin
      if (self[i] <> cur) then
      begin
        if (hits > best) then
        begin
          best := hits;
          Result := cur;
        end;
        hits := 0;
        cur := self[I];
      end;
      Inc(hits);
    end;
    if (hits > best) then
      Result := cur;
  end;
end;

end.
