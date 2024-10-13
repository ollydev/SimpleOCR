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

  TOCRFilter = packed record
    FilterType: EOCRFilterType;

    AnyColorFilter: packed record
      MaxShadowValue: Integer;
      Tolerance: Single;
    end;

    ColorRule: packed record
      Colors: TIntegerArray;
      Tolerances: TSingleArray;
      Invert: Boolean;
    end;

    ThresholdRule: packed record
      Invert: Boolean;
      C: Integer;
    end;

    ShadowRule: packed record
      MaxShadowValue: Integer;
      Tolerance: Single;
    end;

    Blacklist: String;
  end;

function ApplyColorFilter(constref Filter: TOCRFilter; var Matrix: TColorRGBAMatrix; out Bounds: TBox): Boolean;
function ApplyThresholdFilter(constref Filter: TOCRFilter; var Matrix: TColorRGBAMatrix; out Bounds: TBox): Boolean;
function ApplyShadowFilter(constref Filter: TOCRFilter; var Matrix: TColorRGBAMatrix; out Bounds: TBox): Boolean;

implementation

function ApplyColorFilter(constref Filter: TOCRFilter; var Matrix: TColorRGBAMatrix; out Bounds: TBox): Boolean;
var
  Width, Height: Integer;
  Hit, Miss: TColorRGBA;

  procedure ApplyColor(Color: Integer; Tolerance: Single);
  var
    X, Y: Integer;
  begin
    for Y := 0 to Height do
      for X := 0 to Width do
        if SimilarColors(Matrix[Y, X], TColorRGBA(Color), Tolerance) then
        begin
          if (X < Bounds.X1) then Bounds.X1 := X;
          if (Y < Bounds.Y1) then Bounds.Y1 := Y;
          if (X > Bounds.X2) then Bounds.X2 := X;
          if (Y > Bounds.Y2) then Bounds.Y2 := Y;

          Matrix[Y, X] := Hit;
        end else
          Matrix[Y, X] := Miss;
  end;

  procedure ApplyColors(Colors: TIntegerArray; Tolerances: TSingleArray);
  var
    X, Y: Integer;
    I, H: Integer;
  label
    Next;
  begin
    H := High(Colors);

    for Y := 0 to Height do
      for X := 0 to Width do
      begin
        for I := 0 to H do
          if SimilarColors(Matrix[Y, X], TColorRGBA(Colors[I]), Tolerances[I]) then
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
  end;

begin
  if (Length(Filter.ColorRule.Colors) <> Length(Filter.ColorRule.Tolerances)) then
    raise Exception.Create('Invalid color filter, Length(Colors) <> Length(Tolerances)');

  Height := High(Matrix);
  Width  := High(Matrix[0]);

  Bounds.X1 := $FFFFFF;
  Bounds.Y1 := $FFFFFF;
  Bounds.X2 := 0;
  Bounds.Y2 := 0;

  Hit.AsInteger  := $FFFFFF;
  Miss.AsInteger := $000000;
  if Filter.ColorRule.Invert then
    Swap(Hit, Miss);

  if (Length(Filter.ColorRule.Colors) = 1) then
    ApplyColor(Filter.ColorRule.Colors[0], Filter.ColorRule.Tolerances[0])
  else
    ApplyColors(Filter.ColorRule.Colors, Filter.ColorRule.Tolerances);

  Result := (Bounds.X1 <> $FFFFFF) and (Bounds.Y1 <> $FFFFFF) and (Bounds.X2 <> 0) and (Bounds.Y2 <> 0);
end;

// https://github.com/galfar/imaginglib/blob/master/Extensions/ImagingBinary.pas#L79
function ApplyThresholdFilter(constref Filter: TOCRFilter; var Matrix: TColorRGBAMatrix; out Bounds: TBox): Boolean;
var
  Histogram: array[Byte] of Single;
  Level, Max, Min, I, J, NumPixels: Integer;
  Mean, Variance: Single;
  Mu, Omega, LevelMean, LargestMu: Single;
  Greyscale: TByteMatrix;
  Grey: Byte;
  X,Y,W,H: Integer;
begin
  W := Matrix.Width - 1;
  H := Matrix.Height - 1;
  Greyscale := ToGreyScale(Matrix);

  FillByte(Histogram[0], SizeOf(Histogram), 0);
  Min := 255;
  Max := 0;
  Level := 0;
  NumPixels := Length(Matrix[0]) * Length(Matrix);

  // Compute histogram and determine min and max pixel values
  for Y := 0 to H do
    for X := 0 to W do
    begin
      Grey := Greyscale[Y,X];

      Histogram[Grey] := Histogram[Grey] + 1.0;
      if (Grey < Min) then
        Min := Grey;
      if (Grey > Max) then
        Max := Grey;
    end;

  // Normalize histogram
  for I := 0 to 255 do
    Histogram[I] := Histogram[I] / NumPixels;

  // Compute image mean and variance
  Mean := 0.0;
  Variance := 0.0;
  for I := 0 to 255 do
    Mean := Mean + (I + 1) * Histogram[I];
  for I := 0 to 255 do
    Variance := Variance + Sqr(I + 1 - Mean) * Histogram[I];

  // Now finally compute threshold level
  LargestMu := 0;

  for I := 0 to 255 do
  begin
    Omega := 0.0;
    LevelMean := 0.0;

    for J := 0 to I - 1 do
    begin
      Omega := Omega + Histogram[J];
      LevelMean := LevelMean + (J + 1) * Histogram[J];
    end;

    Mu := Sqr(Mean * Omega - LevelMean);
    Omega := Omega * (1.0 - Omega);

    if Omega > 0.0 then
      Mu := Mu / Omega
    else
      Mu := 0;

    if Mu > LargestMu then
    begin
      LargestMu := Mu;
      Level := I;
    end;
  end;

  Level := Level - Filter.ThresholdRule.C;

  Bounds.X1 := $FFFFFF;
  Bounds.Y1 := $FFFFFF;
  Bounds.X2 := 0;
  Bounds.Y2 := 0;

  // Do thresholding using computed level
  for Y := 0 to H do
    for X := 0 to W do
    begin
      if (Filter.ThresholdRule.Invert and (Greyscale[Y, X] <= Level)) or ((not Filter.ThresholdRule.Invert) and (Greyscale[Y, X] >= Level)) then
      begin
        if (X < Bounds.X1) then Bounds.X1 := X;
        if (Y < Bounds.Y1) then Bounds.Y1 := Y;
        if (X > Bounds.X2) then Bounds.X2 := X;
        if (Y > Bounds.Y2) then Bounds.Y2 := Y;

        Matrix[Y, X].AsInteger := $00FFFFFF;
      end else
        Matrix[Y, X].AsInteger := $00000000;
    end;

  Result := (Bounds.X1 <> $FFFFFF) and (Bounds.Y1 <> $FFFFFF) and (Bounds.X2 <> 0) and (Bounds.Y2 <> 0);
end;

function ApplyShadowFilter(constref Filter: TOCRFilter; var Matrix: TColorRGBAMatrix; out Bounds: TBox): Boolean;
var
  X, Y, Width, Height: Integer;
  Size, Count, Color: Integer;
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

    Color := Mode(Colors, Count - 1);
    for Y := 0 to Height do
      for X := 0 to Width do
      begin
        if SimilarColors(Matrix[Y, X], TColorRGBA(Color), Filter.ShadowRule.Tolerance) then
        begin
          if (X < Bounds.X1) then Bounds.X1 := X;
          if (Y < Bounds.Y1) then Bounds.Y1 := Y;
          if (X > Bounds.X2) then Bounds.X2 := X;
          if (Y > Bounds.Y2) then Bounds.Y2 := Y;

          Matrix[Y, X].AsInteger := $FFFFFF;
        end else
          Matrix[Y, X].AsInteger := 0;
      end;

    Result := (Bounds.X1 <> $FFFFFF) and (Bounds.Y1 <> $FFFFFF) and (Bounds.X2 <> 0) and (Bounds.Y2 <> 0);
  end;
end;

end.

