unit simpleocr.filters;

{$i simpleocr.inc}

interface

uses
  classes, sysutils,
  simpleocr.types;

type
  TColorRuleArray = array of packed record
    Color: Int32;
    Tolerance: Int32;
  end;

  TSimpleOCRFilter = record
    function ApplyColorRule(var Matrix: T2DIntegerArray; ColorRuleArray: TColorRuleArray; Invert: Boolean; out Bounds: TBox): Boolean;
    function ApplyShadowRule(var Matrix: T2DIntegerArray; MaxShadow: Int32; Tolerance: Int32; out Bounds: TBox): Boolean;
    function ApplyThresholdRule(var Matrix: T2DIntegerArray; Invert: Boolean; Amount: Integer; out Bounds: TBox): Boolean;
  end;

const
  FILTER_HIT  = 0;
  FILTER_MISS = -1;

var
  SimpleOCRFilter: TSimpleOCRFilter;

implementation

uses
  simpleocr.tpa;

function TSimpleOCRFilter.ApplyColorRule(var Matrix: T2DIntegerArray; ColorRuleArray: TColorRuleArray; Invert: Boolean; out Bounds: TBox): Boolean;
var
  HIT: Int32  = FILTER_HIT;
  MISS: Int32 = FILTER_MISS;
var
  X, Y, Width, Height: Int32;
  I, H: Int32;
  Colors: array of record
    R, G, B: UInt8;
    Tol: Int32;
  end;
  Client: TRGB32Matrix absolute Matrix;
label
  Next;
begin
  H := High(ColorRuleArray);
  if (H = -1) then
    Exit(False);

  SetLength(Colors, H + 1);
  for I := 0 to H do
  begin
    Colors[I].B := ColorRuleArray[I].Color and $FF;
    Colors[I].G := ColorRuleArray[I].Color shr 8 and $FF;
    Colors[I].R := ColorRuleArray[I].Color shr 16 and $FF;
    Colors[I].Tol := ColorRuleArray[I].Tolerance;
  end;

  if Invert then
    Exch(HIT, MISS);

  Height := High(Client);
  Width  := High(Client[0]);

  Bounds.X1 := $FFFFFF;
  Bounds.Y1 := $FFFFFF;
  Bounds.X2 := 0;
  Bounds.Y2 := 0;

  for Y := 0 to Height do
    for X := 0 to Width do
      with Client[Y][X] do
      begin
        for I := 0 to H do
          if (Sqr(R - Colors[I].R) + Sqr(G - Colors[I].G) + Sqr(B - Colors[I].B) <= Colors[I].Tol) then
          begin
            if (X < Bounds.X1) then Bounds.X1 := X;
            if (Y < Bounds.Y1) then Bounds.Y1 := Y;
            if (X > Bounds.X2) then Bounds.X2 := X;
            if (Y > Bounds.Y2) then Bounds.Y2 := Y;

            Matrix[Y][X] := HIT;

            goto Next;
          end;

        Matrix[Y][X] := MISS;

        Next:
      end;

  Result := (Bounds.X1 <> $FFFFFF) and (Bounds.Y1 <> $FFFFFF) and (Bounds.X2 <> 0) and (Bounds.Y2 <> 0);
end;

function TSimpleOCRFilter.ApplyShadowRule(var Matrix: T2DIntegerArray; MaxShadow: Int32; Tolerance: Int32; out Bounds: TBox): Boolean;

  function IsShadow(const X, Y: Int32): Boolean; inline;
  begin
    with TRGB32(Matrix[Y][X]) do
      Result := ((R + G + B) div 3) < MaxShadow;
  end;

var
  X, Y, Width, Height: Int32;
  Size, Count: Int32;
  Colors: TIntegerArray;
  ColorRule: TColorRuleArray;
begin
  Count := 0;
  Size := 256;
  SetLength(Colors, Size);

  Height := High(Matrix);
  Width := High(Matrix[0]);

  for Y := 1 to Height do
    for X := 1 to Width do
    begin
      if IsShadow(X, Y) and (not IsShadow(X-1, Y-1)) then
      begin
        Colors[Count] := Matrix[Y-1][X-1];
        Inc(Count);

        if (Count = Size) then
        begin
          Size *= 2;
          SetLength(Colors, Size);
        end;
      end;
    end;
  if Count = 0 then
    Exit(False);

  SetLength(ColorRule, 1);
  ColorRule[0].Color := Mode(Colors, Count-1);
  ColorRule[0].Tolerance := Tolerance;

  Result := ApplyColorRule(Matrix, ColorRule, False, Bounds);
end;

function TSimpleOCRFilter.ApplyThresholdRule(var Matrix: T2DIntegerArray; Invert: Boolean; Amount: Integer; out Bounds: TBox): Boolean;
var
  I, Size, X, Y, W, H: Int32;
  Threshold: UInt8;
  Counter: Int64;
  Tab: array [0..256] of Int32;
  Temp: T2DIntegerArray;
begin
  H := Length(Matrix);
  W := Length(Matrix[0]);
  Size := (W * H) - 1;

  SetLength(Temp, H, W);

  Dec(W);
  Dec(H);

  //Finding the threshold - While at it set blue-scale to the RGB mean (needed for later).
  Threshold := 0;

  Counter := 0;
  for Y := 0 to H do
    for X := 0 to W do
    begin
      with TRGB32(Matrix[Y][X]) do
        Temp[Y][X] := (B + G + R) div 3;

      Counter += Temp[Y][X];
    end;

  Threshold := (Counter div Size) + Amount;
  for I := 0 to (Threshold - 1) do
    if Invert then
      Tab[I] := FILTER_HIT
    else
      Tab[I] := FILTER_MISS;

  for I := Threshold to 255 do
    if Invert then
      Tab[I] := FILTER_MISS
    else
      Tab[I] := FILTER_HIT;

  Bounds.X1 := $FFFFFF;
  Bounds.Y1 := $FFFFFF;
  Bounds.X2 := 0;
  Bounds.Y2 := 0;

  for Y := 0 to H do
    for X := 0 to W do
    begin
      Matrix[Y][X] := Tab[Temp[Y][X]];

      if (Matrix[Y][X] = FILTER_HIT) then
      begin
        if (X < Bounds.X1) then Bounds.X1 := X;
        if (Y < Bounds.Y1) then Bounds.Y1 := Y;
        if (X > Bounds.X2) then Bounds.X2 := X;
        if (Y > Bounds.Y2) then Bounds.Y2 := Y;
      end;
    end;

  Result := (Bounds.X1 <> $FFFFFF) and (Bounds.Y1 <> $FFFFFF) and (Bounds.X2 <> 0) and (Bounds.Y2 <> 0);
end;

end.

