unit simpleocr.filters;
{==============================================================================]
  Copyright (c) 2021, Jarl `slacky` Holta
  Project: SimpleOCR
  Project URL: https://github.com/slackydev/SimpleOCR
  License: GNU Lesser GPL (http://www.gnu.org/licenses/lgpl.html)
[==============================================================================}

{$i simpleocr.inc}

interface

uses
  Classes, SysUtils,
  simpleocr.types;

type
  EOCRFilterType = (
    ANY_COLOR,
    COLOR,
    THRESHOLD,
    SHADOW,
    INVERT_COLOR
  );

  POCRFilter = ^TOCRFilter;
  TOCRFilter = packed record
    FilterType: EOCRFilterType;

    AnyColorFilter: packed record
      MaxShadowValue: Integer;
      Tolerance: Integer;
    end;

    ColorRule: packed record
      Colors: array of packed record
        Color: Integer;
        Tolerance: Integer;
      end;
      Invert: Boolean;
    end;

    ThresholdRule: packed record
      Amount: Integer;
      Invert: Boolean;
    end;

    ShadowRule: packed record
      MaxShadowValue: Integer;
      Tolerance: Integer;
    end;

    MinCharacterMatch: Char;
  end;

function ApplyColorFilter(Filter: TOCRFilter; var Matrix: TIntegerMatrix; out Bounds: TBox): Boolean;
function ApplyThresholdFilter(Filter: TOCRFilter; var Matrix: TIntegerMatrix; out Bounds: TBox): Boolean;
function ApplyShadowFilter(Filter: TOCRFilter; var Matrix: TIntegerMatrix; out Bounds: TBox): Boolean;

implementation

function ApplyColorFilter(Filter: TOCRFilter; var Matrix: TIntegerMatrix; out Bounds: TBox): Boolean;

  function SimilarColors(const Color1, Color2: TRGB32; const Tolerance: Integer): Boolean; inline;
  begin
    Result := Sqr(Color1.R - Color2.R) + Sqr(Color1.G - Color2.G) + Sqr(Color1.B - Color2.B) <= Tolerance;
  end;

var
  X, Y, Width, Height: Integer;
  I, H: Integer;
  Hit, Miss: Integer;
  Tols: TIntegerArray;
label
  Next;
begin
  H := High(Filter.ColorRule.Colors);

  Height := High(Matrix);
  Width  := High(Matrix[0]);

  Bounds.X1 := $FFFFFF;
  Bounds.Y1 := $FFFFFF;
  Bounds.X2 := 0;
  Bounds.Y2 := 0;

  case Filter.ColorRule.Invert of
    True:
      begin
        Hit  := $000000;
        Miss := $FFFFFF;
      end;
    False:
      begin
        Hit  := $FFFFFF;
        Miss := $000000;
      end;
  end;

  SetLength(Tols, H+1);
  for I:=0 to H do
    Tols[I] := Sqr(Filter.ColorRule.Colors[I].Tolerance);

  for Y := 0 to Height do
    for X := 0 to Width do
      begin
        for I := 0 to H do
          if SimilarColors(TRGB32(Matrix[Y, X]), TRGB32(Filter.ColorRule.Colors[I].Color), Tols[I]) then
          begin
            if (X < Bounds.X1) then Bounds.X1 := X;
            if (Y < Bounds.Y1) then Bounds.Y1 := Y;
            if (X > Bounds.X2) then Bounds.X2 := X;
            if (Y > Bounds.Y2) then Bounds.Y2 := Y;

            Matrix[Y, X] := Hit;

            goto Next;
          end;

        Matrix[Y, X] := Miss;

        Next:
      end;

  Result := (Bounds.X1 <> $FFFFFF) and (Bounds.Y1 <> $FFFFFF) and (Bounds.X2 <> 0) and (Bounds.Y2 <> 0);
end;

function ApplyThresholdFilter(Filter: TOCRFilter; var Matrix: TIntegerMatrix; out Bounds: TBox): Boolean;
var
  X, Y, W, H: Integer;
  Threshold: UInt8;
  Counter: Int64;
  Temp: TIntegerMatrix;
  Hit, Miss: Integer;
begin
  H := Length(Matrix);
  W := Length(Matrix[0]);

  SetLength(Temp, H, W);

  Dec(W);
  Dec(H);

  //Finding the threshold - While at it set blue-scale to the RGB mean (needed for later).
  Threshold := 0;

  Counter := 0;
  for Y := 0 to H do
    for X := 0 to W do
    begin
      with TRGB32(Matrix[Y, X]) do
        Temp[Y, X] := (B + G + R) div 3;

      Counter += Temp[Y, X];
    end;

  Threshold := (Counter div ((W * H) - 1)) + Filter.ThresholdRule.Amount;

  case Filter.ThresholdRule.Invert of
    True:
      begin
        Hit  := $000000;
        Miss := $FFFFFF;
      end;
    False:
      begin
        Hit  := $FFFFFF;
        Miss := $000000;
      end;
  end;

  Bounds.X1 := $FFFFFF;
  Bounds.Y1 := $FFFFFF;
  Bounds.X2 := 0;
  Bounds.Y2 := 0;

  for Y := 0 to H do
    for X := 0 to W do
    begin
      if (Temp[Y, X] > Threshold) then
      begin
        Matrix[Y, X] := Hit;

        if (X < Bounds.X1) then Bounds.X1 := X;
        if (Y < Bounds.Y1) then Bounds.Y1 := Y;
        if (X > Bounds.X2) then Bounds.X2 := X;
        if (Y > Bounds.Y2) then Bounds.Y2 := Y;
      end else
        Matrix[Y, X] := Miss;
    end;

  Result := (Bounds.X1 <> $FFFFFF) and (Bounds.Y1 <> $FFFFFF) and (Bounds.X2 <> 0) and (Bounds.Y2 <> 0);
end;

function ApplyShadowFilter(Filter: TOCRFilter; var Matrix: TIntegerMatrix; out Bounds: TBox): Boolean;

  function IsShadow(const X, Y: Integer): Boolean; inline;
  begin
    with TRGB32(Matrix[Y, X]) do
      Result := ((R + G + B) div 3) < Filter.ShadowRule.MaxShadowValue;
  end;

var
  X, Y, Width, Height: Integer;
  Size, Count: Integer;
  Colors: TIntegerArray;
begin
  Result := False;

  Size := 0;
  Count := 0;
  Colors := [];

  Height := High(Matrix);
  Width := High(Matrix[0]);

  for Y := 1 to Height do
    for X := 1 to Width do
    begin
      if IsShadow(X, Y) and (not IsShadow(X-1, Y-1)) then
      begin
        if (Count = Size) then
        begin
          Size := (Size + 32) * 2;
          SetLength(Colors, Size);
        end;

        Colors[Count] := Matrix[Y-1, X-1];
        Inc(Count);
      end;
    end;

  if (Count > 0) then
  begin
    SetLength(Filter.ColorRule.Colors, 1);
    with Filter.ColorRule.Colors[0] do
    begin
      Color := Mode(Colors, Count - 1);
      Tolerance := Filter.ShadowRule.Tolerance;
    end;

    Result := ApplyColorFilter(Filter, Matrix, Bounds);
  end;
end;

end.

