library SimpleOCR;
{==============================================================================]
  Copyright (c) 2021, Jarl `slacky` Holta
  Project: SimpleOCR
  Project URL: https://github.com/slackydev/SimpleOCR
  License: GNU Lesser GPL (http://www.gnu.org/licenses/lgpl.html)
[==============================================================================}
{$mode objfpc}{$H+}
{$i simpleocr.inc}

uses
  classes, sysutils,
  simpleocr.types, simpleocr.engine;

{$i simbaplugin.inc}

procedure TFontSet_Load(const Params: PParamArray); cdecl;
begin
  PFontSet(Params^[0])^.Load(PString(Params^[1])^, PInt32(Params^[2])^);
end;

procedure TSimpleOCR_DrawText(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  P2DIntegerArray(Result)^ := PSimpleOCR(Params^[0])^.DrawText(PString(Params^[1])^, PFontSet(Params^[2])^);
end;

procedure TSimpleOCR_LocateText(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PSingle(Result)^ := PSimpleOCR(Params^[0])^.LocateText(P2DIntegerArray(Params^[1])^, PString(Params^[2])^, PFontSet(Params^[3])^, PCompareRules(Params^[4])^, PBox(Params^[5])^);
end;

procedure TSimpleOCR_Recognize(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PString(Result)^ := PSimpleOCR(Params^[0])^.Recognize(P2DIntegerArray(Params^[1])^, PCompareRules(Params^[2])^, PFontSet(Params^[3])^);
end;

procedure TSimpleOCR_RecognizeStatic(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PString(Result)^ := PSimpleOCR(Params^[0])^.RecognizeStatic(P2DIntegerArray(Params^[1])^, PCompareRules(Params^[2])^, PFontSet(Params^[3])^, PInt32(Params^[4])^);
end;

procedure TSimpleOCR_RecognizeMulti(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PStringArray(Result)^ := PSimpleOCR(Params^[0])^.RecognizeMulti(P2DIntegerArray(Params^[1])^, PCompareRules(Params^[2])^, PFontSet(Params^[3])^, PBoxArray(Params^[4])^);
end;

initialization
  addGlobalType(
    'packed record                                   ' + LineEnding +
    '  ImageWidth, ImageHeight: Int32;               ' + LineEnding +
    '  Width, Height: Int32;                         ' + LineEnding +
    '  CharacterBounds: TBox;                        ' + LineEnding +
    '  CharacterPoints: TPointArray;                 ' + LineEnding +
    '  CharacterPointsLength: Int32;                 ' + LineEnding +
    '  ShadowPoints: TPointArray;                    ' + LineEnding +
    '  BackgroundPoints: TPointArray;                ' + LineEnding +
    '  BackgroundPointsLength: Int32;                ' + LineEnding +
    '  TotalBounds: TBox;                            ' + LineEnding +
    '  Value: Char;                                  ' + LineEnding +
    'end;',
    'TFontCharacter');

  addGlobalType(
    'packed record                                   ' + LineEnding +
    '  Name: String;                                 ' + LineEnding +
    '  Characters: array[32..126] of TFontCharacter; ' + LineEnding +
    '  SpaceWidth: Int32;                            ' + LineEnding +
    '  MaxWidth: Int32;                              ' + LineEnding +
    '  MaxHeight: Int32;                             ' + LineEnding +
    'end;',
    'TFontSet');

  addGlobalType(
    'packed record                                   ' + LineEnding +
    '  Rule: Int32;                                  ' + LineEnding +
    '                                                ' + LineEnding +
    '  AnyColorRule: packed record                   ' + LineEnding +
    '    MaxShadowValue: Int32;                      ' + LineEnding +
    '    Tolerance: Int32;                           ' + LineEnding +
    '  end;                                          ' + LineEnding +
    '                                                ' + LineEnding +
    '  ColorRule: packed record                      ' + LineEnding +
    '    Colors: array of packed record              ' + LineEnding +
    '      Color: Int32;                             ' + LineEnding +
    '      Tolerance: Int32;                         ' + LineEnding +
    '    end;                                        ' + LineEnding +
    '    Invert: Boolean;                            ' + LineEnding +
    '  end;                                          ' + LineEnding +
    '                                                ' + LineEnding +
    '  ThresholdRule: packed record                  ' + LineEnding +
    '    Amount: Int32;                              ' + LineEnding +
    '    Invert: Boolean;                            ' + LineEnding +
    '  end;                                          ' + LineEnding +
    '                                                ' + LineEnding +
    '  ShadowRule: packed record                     ' + LineEnding +
    '    MaxShadowValue: Int32;                      ' + LineEnding +
    '  end;                                          ' + LineEnding +
    '                                                ' + LineEnding +
    '  MinCharacterMatch: Char;                      ' + LineEnding +
    'end;',
    'TCompareRules');

  addGlobalType(
    'packed record                                   ' + LineEnding +
    '  Font: TFontSet;                               ' + LineEnding +
    '  Client: T2DIntegerArray;                      ' + LineEnding +
    '  Width: Int32;                                 ' + LineEnding +
    '  Height: Int32;                                ' + LineEnding +
    '  SearchArea: TBox;                             ' + LineEnding +
    '  CompareRules: TCompareRules;                  ' + LineEnding +
    'end;',
    'TSimpleOCR');

  addGlobalFunc('procedure TFontSet.Load(constref Font: String; constref Space: Int32 = 4); native;', @TFontSet_Load);

  addGlobalFunc('function TSimpleOCR.DrawText(constref Text: String; constref Font: TFontSet): T2DIntegerArray; native;', @TSimpleOCR_DrawText);
  addGlobalFunc('function TSimpleOCR.LocateText(constref Matrix: T2DIntegerArray; constref Text: String; constref Font: TFontSet; constref CompareRules: TCompareRules; out Bounds: TBox): Single; overload; native;', @TSimpleOCR_LocateText);
  addGlobalFunc('function TSimpleOCR.Recognize(constref Matrix: T2DIntegerArray; constref CompareRules: TCompareRules; constref Font: TFontSet): String; overload; native;', @TSimpleOCR_Recognize);
  addGlobalFunc('function TSimpleOCR.RecognizeMulti(constref Matrix: T2DIntegerArray; constref CompareRules: TCompareRules; constref Font: TFontSet; out Bounds: TBoxArray): TStringArray; overload; native;', @TSimpleOCR_RecognizeMulti);
  addGlobalFunc('function TSimpleOCR.RecognizeStatic(constref Matrix: T2DIntegerArray; constref CompareRules: TCompareRules; constref Font: TFontSet; constref MaxWalk: Int32 = 20): String; overload; native;', @TSimpleOCR_RecognizeStatic);

  addCode(
    'type TOCRAnyColorRule    = type TCompareRules; // 0                                                                                                                                          ' + LineEnding +
    'type TOCRColorRule       = type TCompareRules; // 1                                                                                                                                          ' + LineEnding +
    'type TOCRThresholdRule   = type TCompareRules; // 2                                                                                                                                          ' + LineEnding +
    'type TOCRShadowRule      = type TCompareRules; // 3                                                                                                                                          ' + LineEnding +
    'type TOCRInvertColorRule = type TCompareRules; // 4                                                                                                                                          ' + LineEnding +
    '                                                                                                                                                                                             ' + LineEnding +
    'function TOCRAnyColorRule.Create(Tolerance: Int32; MaxShadowValue: Int32 = 0): TOCRAnyColorRule; static;                                                                                     ' + LineEnding +
    'begin                                                                                                                                                                                        ' + LineEnding +
    '  Result.Rule := 0;                                                                                                                                                                          ' + LineEnding +
    '  Result.AnyColorRule.Tolerance := Tolerance;                                                                                                                                                ' + LineEnding +
    '  Result.AnyColorRule.MaxShadowValue := MaxShadowValue;                                                                                                                                      ' + LineEnding +
    'end;                                                                                                                                                                                         ' + LineEnding +
    '                                                                                                                                                                                             ' + LineEnding +
    'function TOCRColorRule.Create(Colors, Tolerances: TIntegerArray): TOCRColorRule; static; overload;                                                                                           ' + LineEnding +
    'var                                                                                                                                                                                          ' + LineEnding +
    '  I: Int32;                                                                                                                                                                                  ' + LineEnding +
    'begin                                                                                                                                                                                        ' + LineEnding +
    '  if Length(Colors) <> Length(Tolerances) then                                                                                                                                               ' + LineEnding +
    '    raise "TOCRColorRule.Create: Length(Colors) <> Length(Tolerances)";                                                                                                                      ' + LineEnding +
    '                                                                                                                                                                                             ' + LineEnding +
    '  Result.Rule := 1;                                                                                                                                                                          ' + LineEnding +
    '                                                                                                                                                                                             ' + LineEnding +
    '  SetLength(Result.ColorRule.Colors, Length(Colors));                                                                                                                                        ' + LineEnding +
    '  for I := 0 to High(Colors) do                                                                                                                                                              ' + LineEnding +
    '  begin                                                                                                                                                                                      ' + LineEnding +
    '    Result.ColorRule.Colors[I].Color := Colors[I];                                                                                                                                           ' + LineEnding +
    '    Result.ColorRule.Colors[I].Tolerance := Tolerances[I];                                                                                                                                   ' + LineEnding +
    '  end;                                                                                                                                                                                       ' + LineEnding +
    'end;                                                                                                                                                                                         ' + LineEnding +
    '                                                                                                                                                                                             ' + LineEnding +
    'function TOCRColorRule.Create(Colors: TIntegerArray): TOCRColorRule; static; overload;                                                                                                       ' + LineEnding +
    'var                                                                                                                                                                                          ' + LineEnding +
    '  I: Int32;                                                                                                                                                                                  ' + LineEnding +
    'begin                                                                                                                                                                                        ' + LineEnding +
    '  Result.Rule := 1;                                                                                                                                                                          ' + LineEnding +
    '                                                                                                                                                                                             ' + LineEnding +
    '  SetLength(Result.ColorRule.Colors, Length(Colors));                                                                                                                                        ' + LineEnding +
    '  for I := 0 to High(Colors) do                                                                                                                                                              ' + LineEnding +
    '    Result.ColorRule.Colors[I].Color := Colors[I];                                                                                                                                           ' + LineEnding +
    'end;                                                                                                                                                                                         ' + LineEnding +
    '                                                                                                                                                                                             ' + LineEnding +
    'function TOCRInvertColorRule.Create(Colors, Tolerances: TIntegerArray): TOCRInvertColorRule; static; overload;                                                                               ' + LineEnding +
    'var                                                                                                                                                                                          ' + LineEnding +
    '  I: Int32;                                                                                                                                                                                  ' + LineEnding +
    'begin                                                                                                                                                                                        ' + LineEnding +
    '  if Length(Colors) <> Length(Tolerances) then                                                                                                                                               ' + LineEnding +
    '    raise "TOCRColorRule.Create: Length(Colors) <> Length(Tolerances)";                                                                                                                      ' + LineEnding +
    '                                                                                                                                                                                             ' + LineEnding +
    '  Result.Rule := 4;                                                                                                                                                                          ' + LineEnding +
    '  Result.ColorRule.Invert := True;                                                                                                                                                           ' + LineEnding +
    '                                                                                                                                                                                             ' + LineEnding +
    '  SetLength(Result.ColorRule.Colors, Length(Colors));                                                                                                                                        ' + LineEnding +
    '  for I := 0 to High(Colors) do                                                                                                                                                              ' + LineEnding +
    '  begin                                                                                                                                                                                      ' + LineEnding +
    '    Result.ColorRule.Colors[I].Color := Colors[I];                                                                                                                                           ' + LineEnding +
    '    Result.ColorRule.Colors[I].Tolerance := Tolerances[I];                                                                                                                                   ' + LineEnding +
    '  end;                                                                                                                                                                                       ' + LineEnding +
    'end;                                                                                                                                                                                         ' + LineEnding +
    '                                                                                                                                                                                             ' + LineEnding +
    'function TOCRInvertColorRule.Create(Colors: TIntegerArray): TOCRInvertColorRule; static; overload;                                                                                           ' + LineEnding +
    'var                                                                                                                                                                                          ' + LineEnding +
    '  I: Int32;                                                                                                                                                                                  ' + LineEnding +
    'begin                                                                                                                                                                                        ' + LineEnding +
    '  Result.Rule := 4;                                                                                                                                                                          ' + LineEnding +
    '  Result.ColorRule.Invert := True;                                                                                                                                                           ' + LineEnding +
    '                                                                                                                                                                                             ' + LineEnding +
    '  SetLength(Result.ColorRule.Colors, Length(Colors));                                                                                                                                        ' + LineEnding +
    '  for I := 0 to High(Colors) do                                                                                                                                                              ' + LineEnding +
    '    Result.ColorRule.Colors[I].Color := Colors[I];                                                                                                                                           ' + LineEnding +
    'end;                                                                                                                                                                                         ' + LineEnding +
    '                                                                                                                                                                                             ' + LineEnding +
    'function TOCRThresholdRule.Create(Amount: Int32; Invert: Boolean = False): TOCRThresholdRule; static;                                                                                        ' + LineEnding +
    'begin                                                                                                                                                                                        ' + LineEnding +
    '  Result.Rule := 2;                                                                                                                                                                          ' + LineEnding +
    '  Result.ThresholdRule.Amount := Amount;                                                                                                                                                     ' + LineEnding +
    '  Result.ThresholdRule.Invert := Invert;                                                                                                                                                     ' + LineEnding +
    'end;                                                                                                                                                                                         ' + LineEnding +
    '                                                                                                                                                                                             ' + LineEnding +
    'function TOCRShadowRule.Create(MaxShadowValue: Int32 = 85): TOCRShadowRule; static;                                                                                                          ' + LineEnding +
    'begin                                                                                                                                                                                        ' + LineEnding +
    '  Result.Rule := 3;                                                                                                                                                                          ' + LineEnding +
    '  Result.ShadowRule.MaxShadowValue := MaxShadowValue;                                                                                                                                        ' + LineEnding +
    'end;                                                                                                                                                                                         ' + LineEnding +
    '                                                                                                                                                                                             ' + LineEnding +
    'procedure TFontSet.Load(constref Font: String; constref Space: Int32 = 4); override;                                                                                                         ' + LineEnding +
    'begin                                                                                                                                                                                        ' + LineEnding +
    '  if not DirectoryExists(Font) then                                                                                                                                                          ' + LineEnding +
    '    raise "Font directory does not exist: " + Font;                                                                                                                                          ' + LineEnding +
    '  inherited();                                                                                                                                                                               ' + LineEnding +
    'end;                                                                                                                                                                                         ' + LineEnding +
    '                                                                                                                                                                                             ' + LineEnding +
    'function TSimpleOCR.Recognize(constref Area: TBox; constref CompareRules: TCompareRules; constref Font: TFontSet): String; overload;                                                         ' + LineEnding +
    'begin                                                                                                                                                                                        ' + LineEnding +
    '  Result := Self.Recognize(GetColorsMatrix(Area.X1, Area.Y1, Area.X2, Area.Y2), CompareRules, Font);                                                                                         ' + LineEnding +
    'end;                                                                                                                                                                                         ' + LineEnding +
    '                                                                                                                                                                                             ' + LineEnding +
    'function TSimpleOCR.RecognizeStatic(constref Area: TBox; constref CompareRules: TCompareRules; constref Font: TFontSet; constref MaxWalk: Int32 = 20): String; overload;                     ' + LineEnding +
    'begin                                                                                                                                                                                        ' + LineEnding +
    '  Result := Self.RecognizeStatic(GetColorsMatrix(Area.X1, Area.Y1, Area.X2, Area.Y2), CompareRules, Font, MaxWalk);                                                                          ' + LineEnding +
    'end;                                                                                                                                                                                         ' + LineEnding +
    '                                                                                                                                                                                             ' + LineEnding +
    'function TSimpleOCR.RecognizeMulti(constref Area: TBox; constref CompareRules: TCompareRules; constref Font: TFontSet; var Bounds: TBoxArray): TStringArray; overload;                       ' + LineEnding +
    'var                                                                                                                                                                                          ' + LineEnding +
    '  I: Int32;                                                                                                                                                                                  ' + LineEnding +
    'begin                                                                                                                                                                                        ' + LineEnding +
    '  Result := Self.RecognizeMulti(GetColorsMatrix(Area.X1, Area.Y1, Area.X2, Area.Y2), CompareRules, Font, Bounds);                                                                            ' + LineEnding +
    '  for I := 0 to High(Bounds) do                                                                                                                                                              ' + LineEnding +
    '  begin                                                                                                                                                                                      ' + LineEnding +
    '    Bounds[I].X1 += Area.X1;                                                                                                                                                                 ' + LineEnding +
    '    Bounds[I].Y1 += Area.Y1;                                                                                                                                                                 ' + LineEnding +
    '    Bounds[I].X2 += Area.X1;                                                                                                                                                                 ' + LineEnding +
    '    Bounds[I].Y2 += Area.Y1;                                                                                                                                                                 ' + LineEnding +
    '  end;                                                                                                                                                                                       ' + LineEnding +
    'end;                                                                                                                                                                                         ' + LineEnding +
    '                                                                                                                                                                                             ' + LineEnding +
    'function TSimpleOCR.RecognizeMulti(constref Area: TBox; constref CompareRules: TCompareRules; constref Font: TFontSet): TStringArray; overload;                                              ' + LineEnding +
    'var                                                                                                                                                                                          ' + LineEnding +
    '  Bounds: TBoxArray;                                                                                                                                                                         ' + LineEnding +
    'begin                                                                                                                                                                                        ' + LineEnding +
    '  Result := Self.RecognizeMulti(Area, CompareRules, Font, Bounds);                                                                                                                           ' + LineEnding +
    'end;                                                                                                                                                                                         ' + LineEnding +
    '                                                                                                                                                                                             ' + LineEnding +
    'function TSimpleOCR.RecognizeNumber(constref Area: TBox; constref CompareRules: TCompareRules; constref Font: TFontSet): Int64;                                                              ' + LineEnding +
    'var                                                                                                                                                                                          ' + LineEnding +
    '  Text: String;                                                                                                                                                                              ' + LineEnding +
    '  Character: Char;                                                                                                                                                                           ' + LineEnding +
    'begin                                                                                                                                                                                        ' + LineEnding +
    '  for Character in Self.Recognize(Area, CompareRules, Font) do                                                                                                                               ' + LineEnding +
    '    case Character of                                                                                                                                                                        ' + LineEnding +
    '      #48..#57: Text += Character;                                                                                                                                                           ' + LineEnding +
    '           #79: Text += #48;                                                                                                                                                                 ' + LineEnding +
    '    end;                                                                                                                                                                                     ' + LineEnding +
    '                                                                                                                                                                                             ' + LineEnding +
    '  if (Text <> "") then                                                                                                                                                                       ' + LineEnding +
    '    Result := StrToInt(Text);                                                                                                                                                                ' + LineEnding +
    'end;                                                                                                                                                                                         ' + LineEnding +
    '                                                                                                                                                                                             ' + LineEnding +
    'function TSimpleOCR.LocateText(constref Area: TBox; constref Text: String; constref Font: TFontSet; constref CompareRules: TCompareRules; out Bounds: TBox): Single; overload;               ' + LineEnding +
    'begin                                                                                                                                                                                        ' + LineEnding +
    '  Result := Self.LocateText(GetColorsMatrix(Area.X1, Area.Y1, Area.X2, Area.Y2), Text, Font, CompareRules, Bounds);                                                                          ' + LineEnding +
    '  if Result then                                                                                                                                                                             ' + LineEnding +
    '  begin                                                                                                                                                                                      ' + LineEnding +
    '    Bounds.X1 += Area.X1;                                                                                                                                                                    ' + LineEnding +
    '    Bounds.Y1 += Area.Y1;                                                                                                                                                                    ' + LineEnding +
    '    Bounds.X2 += Area.X1;                                                                                                                                                                    ' + LineEnding +
    '    Bounds.Y2 += Area.Y1;                                                                                                                                                                    ' + LineEnding +
    '  end;                                                                                                                                                                                       ' + LineEnding +
    'end;                                                                                                                                                                                         ' + LineEnding +
    '                                                                                                                                                                                             ' + LineEnding +
    'function TSimpleOCR.LocateText(constref Area: TBox; constref Text: String; constref Font: TFontSet; constref CompareRules: TCompareRules; constref MinMatch: Single = 1): Boolean; overload; ' + LineEnding +
    'var                                                                                                                                                                                          ' + LineEnding +
    '  Bounds: TBox;                                                                                                                                                                              ' + LineEnding +
    'begin                                                                                                                                                                                        ' + LineEnding +
    '  Result := Self.LocateText(Area, Text, Font, CompareRules, Bounds) >= MinMatch;                                                                                                             ' + LineEnding +
    'end;                                                                                                                                                                                         ' + LineEnding +
    '                                                                                                                                                                                             ' + LineEnding +
    'procedure TSimpleOCR.DrawText(Bitmap: TMufasaBitmap; constref Font: TFontSet; Text: String; Position: TPoint; Color: TColor); overload;                                                      ' + LineEnding +
    'var                                                                                                                                                                                          ' + LineEnding +
    '  X, Y, W, H: Int32;                                                                                                                                                                         ' + LineEnding +
    '  Matrix: T2DIntegerArray := Self.DrawText(Text, Font);                                                                                                                                      ' + LineEnding +
    'begin                                                                                                                                                                                        ' + LineEnding +
    '  H := High(Matrix);                                                                                                                                                                         ' + LineEnding +
    '  if (H > -1) then                                                                                                                                                                           ' + LineEnding +
    '    W := High(Matrix[0]);                                                                                                                                                                    ' + LineEnding +
    '                                                                                                                                                                                             ' + LineEnding +
    '  for Y := 0 to H do                                                                                                                                                                         ' + LineEnding +
    '    for X := 0 to W do                                                                                                                                                                       ' + LineEnding +
    '      if (Matrix[Y, X] = 255) then                                                                                                                                                           ' + LineEnding +
    '        Bitmap.SetPixel(Position.X + X, Position.Y + Y, Color);                                                                                                                              ' + LineEnding +
    'end;                                                                                                                                                                                         '
  );

end.
