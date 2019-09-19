unit simpleocr.engine;
{==============================================================================]
  Copyright (c) 2019, Jarl `slacky` Holta
  Project: SimpleOCR
  Project URL: https://github.com/slackydev/SimpleOCR
  License: GNU Lesser GPL (http://www.gnu.org/licenses/lgpl.html)
[==============================================================================}
{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  sysutils,
  simpleocr.tpa, simpleocr.types;

type
  PFontChar = ^TFontChar;
  TFontChar = packed record
    FChar:AnsiChar;
    FWidth,FHeight:Int32;
    loaded, hasShadow:LongBool;
    CharacterPoints: TPointArray;
    ShadowPoints: TPointArray;
    BackgroundPoints: TPointArray;
  end;
  TFontChars = Array of TFontChar;

  PFontSet = ^TFontSet;
  TFontSet = packed record
    Name: String;
    Data: TFontChars;
    SpaceWidth: Int32;

    procedure Load(FontPath:String; Space:Int32);
  end;

  PCompareRules = ^TCompareRules;
  TCompareRules = packed record
    Color, ColorMaxDiff: Int32; //-1 = any color
    UseShadow: LongBool;
    ShadowMaxValue:Int32;
    Threshold: Int32;
    ThreshInv: LongBool;
  end;

  PSimpleOCR = ^TSimpleOCR;
  TSimpleOCR = packed record
    Font: TFontSet;
    Client: T2DIntegerArray;
    Width: Int32;
    Height: Int32;

    function CompareChar(Character: TFontChar; Offset: TPoint; Info: TCompareRules): Int32;
    function Recognize(AClient: T2DIntegerArray; Filter:TCompareRules; FontSet: TFontSet; MaxWalk: Int32): String;
  end;

implementation

uses
  graphtype, intfgraphics, lazfileutils, math;

function FindColor(Data: PRGB32; Color: Int32; Width, Height: Int32): TPointArray;
var
  x,y,idx,c:Int32;
  Target: TRGB32;
begin
  Target.R := Color and $FF;
  Target.G := Color shr 8 and $FF;
  Target.B := Color shr 16 and $FF;
  Target.A := 0;

  c := 0;
  idx := 0;
  SetLength(Result, Width*Height);
  for y:=0 to Height-1 do
    for x:=0 to Width-1 do
    begin
      if (Data[idx].R = Target.R) and (Data[idx].G = Target.G) and (Data[idx].B = Target.B) then
      begin
        Result[c].x := x;
        Result[c].y := y;
        Inc(c);
      end;
      Inc(idx);
    end;
  SetLength(Result, c);
end;

type
  TThreshMethod = (tmMean, tmMinMax);

procedure ThresholdAdaptive(var Matrix: T2DIntegerArray; Alpha, Beta: Byte; Invert: Boolean; Method: TThreshMethod; C: Integer);
var
  i, Size, X, Y, W, H: Int32;
  vMin, vMax, threshold: UInt8;
  Counter: Int64;
  Tab: array [0..256] of UInt8;
  Temp: T2DIntegerArray;
begin
  if Alpha = Beta then Exit;
  if Invert then Exch(Alpha, Beta);

  H := Length(Matrix);
  W := Length(Matrix[0]);
  Size := (W * H) - 1;

  SetLength(Temp, H, W);

  Dec(W);
  Dec(H);

  //Finding the threshold - While at it set blue-scale to the RGB mean (needed for later).
  Threshold := 0;

  case Method of
    //Find the Arithmetic Mean / Average.
    tmMean:
    begin
      Counter := 0;
      for Y := 0 to H do
        for X := 0 to W do
        begin
          with TRGB32(Matrix[Y][X]) do
            Temp[Y][X] := (B + G + R) div 3;

          Counter += Temp[Y][X];
        end;

      Threshold := (Counter div Size) + C;
    end;

    tmMinMax:
    begin
      vMin := 255;
      vMax := 0;

      for Y := 0 to H do
        for X := 0 to W do
        begin
          with TRGB32(Matrix[Y][X]) do
            Temp[Y][X] := (B + G + R) div 3;

          if Temp[Y][X] < vMin then
            vMin := Temp[y][X]
          else
          if Temp[Y][X] > vMax then
            vMax := Temp[Y][X];
        end;

      Threshold := ((vMax + Int32(vMin)) shr 1) + C;
    end;
  end;

  for i := 0 to (Threshold - 1) do Tab[i] := Alpha;
  for i := Threshold to 255 do Tab[i] := Beta;

  for Y := 0 to H do
    for X := 0 to W do
      Matrix[Y][X] := Tab[Temp[Y][X]];
end;

//--| TFontSet |--------------------------------------------------------------\\
procedure TFontSet.Load(FontPath: String; Space: Int32);
var
  i: Int32;
  ShadowBounds, CharacterBounds: TBox;
  Image: TLazIntfImage;
  Description: TRawImageDescription;
begin
  Self.Name := ExtractFileNameOnly(FontPath);
  Self.SpaceWidth := Space;

  FontPath := IncludeTrailingPathDelimiter(FontPath);
  if not DirectoryExists(FontPath) then
    raise Exception.CreateFmt('SimpleOCR: Font "%s" does not exist', [FontPath]);

  Description.Init_BPP32_B8G8R8_BIO_TTB(0, 0);

  Image := TLazIntfImage.Create(0, 0);
  Image.DataDescription := Description;

  SetLength(Data, 256);

  for i := 0 to 255 do
  begin
    Data[i].Loaded := False;

    if FileExists(FontPath + IntToStr(i) + '.bmp') then
    begin
      Image.LoadFromFile(FontPath + IntToStr(i) + '.bmp');

      Data[i].FChar := Chr(i);
      Data[i].CharacterPoints := FindColor(PRGB32(Image.PixelData), $FFFFFF, Image.Width, Image.Height);
      Data[i].Loaded := Length(Data[i].CharacterPoints) > 0;

      if Data[i].Loaded then
      begin
        Data[i].ShadowPoints := FindColor(PRGB32(Image.PixelData), $0000FF, Image.Width, Image.Height);
        Data[i].HasShadow := Length(Data[i].ShadowPoints) > 0;

        ShadowBounds := TPABounds(Data[i].ShadowPoints);
        CharacterBounds := TPABounds(Data[i].CharacterPoints);

        if CharacterBounds.X1 > 0 then
        begin
          OffsetTPA(Data[i].CharacterPoints, -CharacterBounds.X1,0);
          SortTPAByColumn(Data[i].CharacterPoints);
          if Data[i].HasShadow then
            OffsetTPA(Data[i].ShadowPoints, -CharacterBounds.X1, 0);

          Data[i].BackgroundPoints := InvertTPA(CombineTPA(Data[i].CharacterPoints, Data[i].ShadowPoints));
        end;

        Data[i].FWidth  := Max(CharacterBounds.X2 - CharacterBounds.X1, ShadowBounds.X2 - ShadowBounds.X1) + 1;
        Data[i].FHeight := Max(CharacterBounds.Y2, ShadowBounds.Y2)+1;
      end;
    end;
  end;

  Image.Free();
end;

function TSimpleOCR.CompareChar(Character: TFontChar; Offset: TPoint; Info: TCompareRules): Int32;
var
  i,Hits,Any, MaxShadow:Int32;
  First,Color:TRGB32;
  P:TPoint;
begin
  Hits := 0;
  Any := 0;

  if (Info.Color = -1) then
  begin
    P := Character.CharacterPoints[0];
    P.X += Offset.X;
    P.Y += Offset.Y;
    if (P.X >= Self.Width) or (P.Y >= Self.Height) or (P.X < 0) or (P.Y < 0) then
      Exit(-1);

    First := TRGB32(Client[P.Y, P.X]);
    if Info.UseShadow then
    begin
      MaxShadow := 2 * Info.ShadowMaxValue;
      if ((First.R + First.G + First.B) div 3 < 85) and ((First.R < MaxShadow) and (First.G < MaxShadow) and (First.B < MaxShadow)) then
        Exit(-1);
    end;
  end else
    First := TRGB32(Info.Color);

  //count hits for the character
  for i := 0 to High(Character.CharacterPoints) do
  begin
    P := Character.CharacterPoints[i];
    P.X += Offset.X;
    P.Y += Offset.Y;
    if (P.X >= Self.Width) or (P.Y >= Self.Height) or (P.X < 0) or (P.Y < 0) then
      Exit(-1);

    Color := TRGB32(Client[P.Y, P.X]);
    if not( Sqr(Color.R - First.R) + Sqr(Color.B - First.B) + Sqr(Color.G - First.G) <= Info.ColorMaxDiff ) then
      Exit(-1)
    else
      Inc(Hits, 2);
  end;

  if Hits < Length(Character.CharacterPoints) then Exit(-1); //<50% match.

  if not Info.UseShadow then
  begin
    //counts hits for the points that should not have equal Color to character
    //not needed for shadow-fonts
    for i := 0 to High(Character.BackgroundPoints) do
    begin
      P := Character.BackgroundPoints[i];
      P.X += Offset.X;
      P.Y += Offset.Y;
      if (P.X >= Self.Width) or (P.Y >= Self.Height) or (P.X < 0) or (P.Y < 0) then
        Exit(-1);

      Color := TRGB32(Client[P.Y,P.X]);
      if Sqr(Color.R - First.R) + Sqr(Color.B - First.B) + Sqr(Color.G - First.G) > Info.ColorMaxDiff then
        Inc(Any)
      else
        Dec(Hits);
    end;

    if (Length(Character.BackgroundPoints) > 0) and (Any <= (Length(Character.BackgroundPoints) div 2)) then
      Exit(-1) //<=50% match.
    else
      Inc(Hits, Any);
  end else
  begin
    //count hits for font-shadow
    for i := 0 to High(Character.ShadowPoints) do
    begin
      P := Character.ShadowPoints[i];
      P.X += Offset.X;
      P.Y += Offset.Y;
      if (P.X >= Self.Width) or (P.Y >= Self.Height) or (P.X < 0) or (P.Y < 0) then
        Exit(-1);

      Color := TRGB32(Client[P.Y, P.X]);

      if not((Color.R < Info.ShadowMaxValue) and (Color.G < Info.ShadowMaxValue) and (Color.B < Info.ShadowMaxValue)) then
        Exit(-1)
      else
        Inc(Hits);
    end;
  end;

  Result := Hits;
end;

function TSimpleOCR.Recognize(AClient: T2DIntegerArray; Filter: TCompareRules; FontSet: TFontSet; MaxWalk: Int32): String;

  // This makes SimpleOCR a little more dynamic where it doesn't need the perfect bounds that is in line with the fonts glpyhs.
  // Should be able to just expand the bounds of the text by 1 (to account if your font has a shadow) and SimpleOCR should function well.
  procedure SearchForCharacter(out offX, offY: Int32);
  var
    bestID, bestCount, Hits, X, Y: Int32;
    i: Int32;
  begin
    bestID := -1;
    bestCount := 0;

    for X := -3 to 3 do  // Maybe add a parameter of how far to search?
      for Y := -3 to 3 do
      begin
        for i := 0 to High(Font.Data) do
        begin
          if (not Font.Data[i].Loaded) then
            Continue;

          Hits := Self.CompareChar(Font.Data[i], Point(X, Y), Filter);

          if Hits > bestCount then
          begin
            bestID := i;
            bestCount := hits;

            offX := X + Font.Data[bestID].FWidth;
            offY := Y;
          end;
        end;
      end;

    if (bestID > -1) and (bestCount > 0) then
      Result := Font.Data[bestID].FChar;
  end;

var
  Space, i, X, Y: Int32;
  Hits, bestID, bestCount: Int32;
begin
  Result := '';

  Self.Font := FontSet;
  Self.Client := AClient;
  if (Length(Self.Client) = 0) or (Length(Client[0]) = 0) or (Length(Font.Data) = 0) then
    Exit;

  Self.Width := Length(Client[0]);
  Self.Height := Length(Client);

  if (Filter.Color = -1) and (not Filter.UseShadow) then
  begin
    ThresholdAdaptive(Self.Client, 0, 255, Filter.ThreshInv, tmMean, Filter.Threshold);

    Filter.Color := 255;
  end;

  Filter.ColorMaxDiff := Sqr(Filter.ColorMaxDiff);

  SearchForCharacter(X, Y);

  if (Result <> '') then // InitialRecognize found us a starting character
  begin
    Space := 0;

    while (X < Self.Width) and (Space < MaxWalk) do
    begin
      bestID := -1;
      bestCount := 0;

      for i := 0 to High(Font.Data) do
      begin
        if (not Font.Data[i].Loaded) or (Width - X < Font.Data[i].FWidth) then
          Continue;

        Hits := Self.CompareChar(Font.Data[i], Point(X, Y), Filter);
        if Hits > bestCount then
        begin
          bestID := i;
          bestCount := hits;
        end;
      end;

      if (bestID > -1) and (bestCount > 0) then
      begin
        if (Space >= Font.SpaceWidth) then
          Result += #32;

        Space := 0;

        X += Font.Data[bestID].FWidth;
        Result += Font.Data[bestID].FChar;

        Continue;
      end else
        Space += 1;

      X += 1;
    end;
  end;
end;

end.



