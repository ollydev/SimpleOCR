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
  simpleocr.base;

type
  EOCRFilterType = (
    ANY_COLOR,
    COLOR,
    THRESHOLD,
    SHADOW,
    INVERT_COLOR
  );

  TOCRFilter = record
    FilterType: EOCRFilterType;

    AnyColorFilter: record
      MaxShadowValue: Integer;
      Tolerance: Single;
    end;

    ColorRule: record
      Colors: array of record
        Color: Integer;
        Tolerance: Single;
      end;
      Invert: Boolean;
    end;

    ThresholdRule: record
      Amount: Integer;
      Invert: Boolean;
    end;

    ShadowRule: record
      MaxShadowValue: Integer;
      Tolerance: Single;
    end;

    Blacklist: String;
  end;

function ApplyColor(Color: Integer; Tolerance: Single; Invert: Boolean; var Matrix: TColorRGBAMatrix; out Bounds: TBox): Boolean;
function ApplyColors(Colors: TIntegerArray; Tols: TSingleArray; Invert: Boolean; var Matrix: TColorRGBAMatrix; out Bounds: TBox): Boolean;

function ApplyColorFilter(constref Filter: TOCRFilter; var Matrix: TColorRGBAMatrix; out Bounds: TBox): Boolean;
function ApplyThresholdFilter(constref Filter: TOCRFilter; var Matrix: TColorRGBAMatrix; out Bounds: TBox): Boolean;
function ApplyShadowFilter(constref Filter: TOCRFilter; var Matrix: TColorRGBAMatrix; out Bounds: TBox): Boolean;

implementation

function ApplyColor(Color: Integer; Tolerance: Single; Invert: Boolean; var Matrix: TColorRGBAMatrix; out Bounds: TBox): Boolean;
var
  Width, Height: Integer;
  X, Y: Integer;
  IsSimilar: Boolean;
begin
  Height := High(Matrix);
  Width  := High(Matrix[0]);

  Bounds.X1 := $FFFFFF;
  Bounds.Y1 := $FFFFFF;
  Bounds.X2 := 0;
  Bounds.Y2 := 0;

  for Y := 0 to Height do
    for X := 0 to Width do
    begin
      IsSimilar := SimilarColors(TColorRGBA(Matrix[Y, X]), TColorRGBA(Color), Tolerance);

      if IsSimilar <> Invert then
      begin
        if (X < Bounds.X1) then Bounds.X1 := X;
        if (Y < Bounds.Y1) then Bounds.Y1 := Y;
        if (X > Bounds.X2) then Bounds.X2 := X;
        if (Y > Bounds.Y2) then Bounds.Y2 := Y;

        Matrix[Y, X].AsInteger := $FFFFFF;
      end else
        Matrix[Y, X].AsInteger := $000000;
    end;

  Result := (Bounds.X1 <> $FFFFFF) and (Bounds.Y1 <> $FFFFFF) and (Bounds.X2 <> 0) and (Bounds.Y2 <> 0);
end;

function ApplyColors(Colors: TIntegerArray; Tols: TSingleArray; Invert: Boolean; var Matrix: TColorRGBAMatrix; out Bounds: TBox): Boolean;
var
  Width, Height: Integer;
  X, Y, I: Integer;
  IsSimilar: Boolean;
begin
  Height := High(Matrix);
  Width  := High(Matrix[0]);

  Bounds.X1 := $FFFFFF;
  Bounds.Y1 := $FFFFFF;
  Bounds.X2 := 0;
  Bounds.Y2 := 0;

  for Y := 0 to Height do
    for X := 0 to Width do
    begin
      IsSimilar := False;
      for I := 0 to High(Colors) do
      begin
        IsSimilar := SimilarColors(TColorRGBA(Matrix[Y, X]), TColorRGBA(Colors[I]), Tols[I]);
        if IsSimilar then
          Break;
      end;

      if IsSimilar <> Invert then
      begin
        if (X < Bounds.X1) then Bounds.X1 := X;
        if (Y < Bounds.Y1) then Bounds.Y1 := Y;
        if (X > Bounds.X2) then Bounds.X2 := X;
        if (Y > Bounds.Y2) then Bounds.Y2 := Y;

        Matrix[Y, X].AsInteger := $FFFFFF;
      end else
        Matrix[Y, X].AsInteger := $000000;
    end;

  Result := (Bounds.X1 <> $FFFFFF) and (Bounds.Y1 <> $FFFFFF) and (Bounds.X2 <> 0) and (Bounds.Y2 <> 0);
end;

function ApplyColorFilter(constref Filter: TOCRFilter; var Matrix: TColorRGBAMatrix; out Bounds: TBox): Boolean;
var
  Cols: TIntegerArray;
  Tols: TSingleArray;
  I: Integer;
begin
  if Length(Filter.ColorRule.Colors) = 1 then
    Result := ApplyColor(Filter.ColorRule.Colors[0].Color, Filter.ColorRule.Colors[0].Tolerance, Filter.ColorRule.Invert, Matrix, Bounds)
  else
  begin
    SetLength(Cols, Length(Filter.ColorRule.Colors));
    SetLength(Tols, Length(Filter.ColorRule.Colors));
    for I := 0 to High(Filter.ColorRule.Colors) do
    begin
      Cols[I] := Filter.ColorRule.Colors[I].Color;
      Tols[I] := Filter.ColorRule.Colors[I].Tolerance;
    end;

    Result := ApplyColors(Cols, Tols, Filter.ColorRule.Invert, Matrix, Bounds);
  end;
end;

function ApplyThresholdFilter(constref Filter: TOCRFilter; var Matrix: TColorRGBAMatrix; out Bounds: TBox): Boolean;
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
      with TColorRGBA(Matrix[Y, X]) do
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
        Matrix[Y, X].AsInteger := Hit;

        if (X < Bounds.X1) then Bounds.X1 := X;
        if (Y < Bounds.Y1) then Bounds.Y1 := Y;
        if (X > Bounds.X2) then Bounds.X2 := X;
        if (Y > Bounds.Y2) then Bounds.Y2 := Y;
      end else
        Matrix[Y, X].AsInteger := Miss;
    end;

  Result := (Bounds.X1 <> $FFFFFF) and (Bounds.Y1 <> $FFFFFF) and (Bounds.X2 <> 0) and (Bounds.Y2 <> 0);
end;

function ApplyShadowFilter(constref Filter: TOCRFilter; var Matrix: TColorRGBAMatrix; out Bounds: TBox): Boolean;
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
      if IsShadow(Matrix[Y, X], Filter.ShadowRule.MaxShadowValue) and (not IsShadow(Matrix[Y-1, X-1], Filter.ShadowRule.MaxShadowValue)) then
      begin
        if (Count = Size) then
        begin
          Size := (Size + 32) * 2;
          SetLength(Colors, Size);
        end;

        Colors[Count] := Matrix[Y-1, X-1].AsInteger;
        Inc(Count);
      end;
    end;


  if (Count > 0) then
  begin
    Bounds.X1 := $FFFFFF;
    Bounds.Y1 := $FFFFFF;
    Bounds.X2 := 0;
    Bounds.Y2 := 0;

    ApplyColor(Mode(Colors, Count - 1), Filter.ShadowRule.Tolerance, False, Matrix, Bounds);

    Result := (Bounds.X1 <> $FFFFFF) and (Bounds.Y1 <> $FFFFFF) and (Bounds.X2 <> 0) and (Bounds.Y2 <> 0);
  end;
end;

end.

