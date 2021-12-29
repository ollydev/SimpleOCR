library SimpleOCR;
{==============================================================================]
  Copyright (c) 2021, Jarl `slacky` Holta
  Project: SimpleOCR
  Project URL: https://github.com/slackydev/SimpleOCR
  License: GNU Lesser GPL (http://www.gnu.org/licenses/lgpl.html)
[==============================================================================}
{$i simpleocr.inc}

uses
  classes, sysutils,
  simpleocr.types, simpleocr.engine;

{$i simbaplugin.inc}

procedure TFontSet_Load(const Params: PParamArray); cdecl;
begin
  PFontSet(Params^[0])^.Load(PString(Params^[1])^, PInteger(Params^[2])^);
end;

procedure TSimpleOCR_TextToMatrix(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  P2DIntegerArray(Result)^ := PSimpleOCR(Params^[0])^.TextToMatrix(PString(Params^[1])^, PFontSet(Params^[2])^);
end;

procedure TSimpleOCR_TextToTPA(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PPointArray(Result)^ := PSimpleOCR(Params^[0])^.TextToTPA(PString(Params^[1])^, PFontSet(Params^[2])^);
end;

procedure TSimpleOCR_LocateText(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PSingle(Result)^ := PSimpleOCR(Params^[0])^.LocateText(PString(Params^[1])^, PFontSet(Params^[2])^, POCRFilter(Params^[3])^, PBox(Params^[4])^);
end;

procedure TSimpleOCR_LocateTextEx(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PSingle(Result)^ := PSimpleOCR(Params^[0])^.LocateText(PString(Params^[1])^, PFontSet(Params^[2])^, PBox(Params^[3])^);
end;

procedure TSimpleOCR_Recognize(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PString(Result)^ := PSimpleOCR(Params^[0])^.Recognize(POCRFilter(Params^[1])^, PFontSet(Params^[2])^);
end;

procedure TSimpleOCR_RecognizeUpText(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PString(Result)^ := PSimpleOCR(Params^[0])^.RecognizeUpText(POCRFilter(Params^[1])^, PFontSet(Params^[2])^, PInteger(Params^[3])^);
end;

procedure TSimpleOCR_RecognizeStatic(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PString(Result)^ := PSimpleOCR(Params^[0])^.RecognizeStatic(POCRFilter(Params^[1])^, PFontSet(Params^[2])^, PInteger(Params^[3])^);
end;

procedure TSimpleOCR_RecognizeLines(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PStringArray(Result)^ := PSimpleOCR(Params^[0])^.RecognizeLines(POCRFilter(Params^[1])^, PFontSet(Params^[2])^, PBoxArray(Params^[3])^);
end;

procedure TSimpleOCR_RecognizeLinesEx(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PStringArray(Result)^ := PSimpleOCR(Params^[0])^.RecognizeLines(POCRFilter(Params^[1])^, PFontSet(Params^[2])^);
end;

initialization
  addGlobalType(
    'packed record                                   ' + LineEnding +
    '  ImageWidth, ImageHeight: Integer;             ' + LineEnding +
    '  Width, Height: Integer;                       ' + LineEnding +
    '  CharacterBounds: TBox;                        ' + LineEnding +
    '  CharacterPoints: TPointArray;                 ' + LineEnding +
    '  CharacterPointsLength: Integer;               ' + LineEnding +
    '  ShadowPoints: TPointArray;                    ' + LineEnding +
    '  BackgroundPoints: TPointArray;                ' + LineEnding +
    '  BackgroundPointsLength: Integer;              ' + LineEnding +
    '  TotalBounds: TBox;                            ' + LineEnding +
    '  Value: Char;                                  ' + LineEnding +
    'end;',
    'TFontCharacter');

  addGlobalType(
    'packed record                                   ' + LineEnding +
    '  Name: String;                                 ' + LineEnding +
    '  Characters: array[32..126] of TFontCharacter; ' + LineEnding +
    '  SpaceWidth: Integer;                          ' + LineEnding +
    '  MaxWidth: Integer;                            ' + LineEnding +
    '  MaxHeight: Integer;                           ' + LineEnding +
    'end;',
    'TFontSet');

  addGlobalType(
    'packed record                                   ' + LineEnding +
    '  Rule: Integer;                                ' + LineEnding +
    '                                                ' + LineEnding +
    '  UpTextFilter: packed record                   ' + LineEnding +
    '    MaxShadowValue: Integer;                    ' + LineEnding +
    '    Tolerance: Integer;                         ' + LineEnding +
    '  end;                                          ' + LineEnding +
    '                                                ' + LineEnding +
    '  ColorFilter: packed record                    ' + LineEnding +
    '    Colors: array of packed record              ' + LineEnding +
    '      Color: Integer;                           ' + LineEnding +
    '      Tolerance: Integer;                       ' + LineEnding +
    '    end;                                        ' + LineEnding +
    '    Invert: Boolean;                            ' + LineEnding +
    '  end;                                          ' + LineEnding +
    '                                                ' + LineEnding +
    '  ThresholdFilter: packed record                ' + LineEnding +
    '    Amount: Integer;                            ' + LineEnding +
    '    Invert: Boolean;                            ' + LineEnding +
    '  end;                                          ' + LineEnding +
    '                                                ' + LineEnding +
    '  ShadowFilter: packed record                   ' + LineEnding +
    '    MaxShadowValue: Integer;                    ' + LineEnding +
    '    Tolerance: Integer;                         ' + LineEnding +
    '  end;                                          ' + LineEnding +
    '                                                ' + LineEnding +
    '  MinCharacterMatch: Char;                      ' + LineEnding +
    'end;',
    'TOCRFilter');

  addGlobalType(
    'packed record                                   ' + LineEnding +
    '  Font: TFontSet;                               ' + LineEnding +
    '  Client: T2DIntegerArray;                      ' + LineEnding +
    '  Width: Integer;                               ' + LineEnding +
    '  Height: Integer;                              ' + LineEnding +
    '  SearchArea: TBox;                             ' + LineEnding +
    'end;',
    'TSimpleOCR');

  addGlobalFunc('procedure TFontSet.Load(constref Font: String; Space: Integer = 4); native;', @TFontSet_Load);

  addGlobalFunc('function TSimpleOCR.TextToMatrix(constref Text: String; constref Font: TFontSet): T2DIntegerArray; native;', @TSimpleOCR_TextToMatrix);
  addGlobalFunc('function TSimpleOCR.TextToTPA(constref Text: String; constref Font: TFontSet): TPointArray; native;', @TSimpleOCR_TextToTPA);

  addGlobalFunc('function TSimpleOCR._LocateText(constref Text: String; constref Font: TFontSet; constref Filter: TOCRFilter; out Bounds: TBox): Single; overload; native;', @TSimpleOCR_LocateText);
  addGlobalFunc('function TSimpleOCR._LocateText(constref Text: String; constref Font: TFontSet; out Bounds: TBox): Single; overload; native;', @TSimpleOCR_LocateTextEx);

  addGlobalFunc('function TSimpleOCR._Recognize(constref Filter: TOCRFilter; constref Font: TFontSet): String; native;', @TSimpleOCR_Recognize);
  addGlobalFunc('function TSimpleOCR._RecognizeLines(constref Filter: TOCRFilter; constref Font: TFontSet; out Bounds: TBoxArray): TStringArray; overload; native;', @TSimpleOCR_RecognizeLines);
  addGlobalFunc('function TSimpleOCR._RecognizeLines(constref Filter: TOCRFilter; constref Font: TFontSet): TStringArray; overload; native;', @TSimpleOCR_RecognizeLinesEx);
  addGlobalFunc('function TSimpleOCR._RecognizeStatic(constref Filter: TOCRFilter; constref Font: TFontSet; MaxWalk: Integer = 20): String; native;', @TSimpleOCR_RecognizeStatic);
  addGlobalFunc('function TSimpleOCR._RecognizeUpText(constref Filter: TOCRFilter; constref Font: TFontSet; MaxWalk: Integer = 20): String; native;', @TSimpleOCR_RecognizeUpText);

  addCode(
    'type TOCRUpTextFilter      = type TOCRFilter; // 0                                                                                                                                  ' + LineEnding +
    'type TOCRColorFilter       = type TOCRFilter; // 1                                                                                                                                  ' + LineEnding +
    'type TOCRThresholdFilter   = type TOCRFilter; // 2                                                                                                                                  ' + LineEnding +
    'type TOCRShadowFilter      = type TOCRFilter; // 3                                                                                                                                  ' + LineEnding +
    'type TOCRInvertColorFilter = type TOCRFilter; // 4                                                                                                                                  ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    'function TOCRUpTextFilter.Create(Tolerance: Integer; MaxShadowValue: Integer): TOCRUpTextFilter; static;                                                                            ' + LineEnding +
    'begin                                                                                                                                                                               ' + LineEnding +
    '  Result.Rule := 0;                                                                                                                                                                 ' + LineEnding +
    '  Result.UpTextFilter.Tolerance := Sqr(Tolerance);                                                                                                                                  ' + LineEnding +
    '  Result.UpTextFilter.MaxShadowValue := MaxShadowValue;                                                                                                                             ' + LineEnding +
    'end;                                                                                                                                                                                ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    'function TOCRColorFilter.Create(Colors, Tolerances: TIntegerArray): TOCRColorFilter; static; overload;                                                                              ' + LineEnding +
    'var                                                                                                                                                                                 ' + LineEnding +
    '  I: Integer;                                                                                                                                                                       ' + LineEnding +
    'begin                                                                                                                                                                               ' + LineEnding +
    '  if Length(Colors) <> Length(Tolerances) then                                                                                                                                      ' + LineEnding +
    '    raise "TOCRColorFilter.Create: Length(Colors) <> Length(Tolerances)";                                                                                                           ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    '  Result.Rule := 1;                                                                                                                                                                 ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    '  SetLength(Result.ColorFilter.Colors, Length(Colors));                                                                                                                             ' + LineEnding +
    '  for I := 0 to High(Colors) do                                                                                                                                                     ' + LineEnding +
    '  begin                                                                                                                                                                             ' + LineEnding +
    '    Result.ColorFilter.Colors[I].Color := Colors[I];                                                                                                                                ' + LineEnding +
    '    Result.ColorFilter.Colors[I].Tolerance := Sqr(Tolerances[I]);                                                                                                                   ' + LineEnding +
    '  end;                                                                                                                                                                              ' + LineEnding +
    'end;                                                                                                                                                                                ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    'function TOCRColorFilter.Create(Colors: TIntegerArray): TOCRColorFilter; static; overload;                                                                                          ' + LineEnding +
    'var                                                                                                                                                                                 ' + LineEnding +
    '  I: Integer;                                                                                                                                                                       ' + LineEnding +
    'begin                                                                                                                                                                               ' + LineEnding +
    '  Result.Rule := 1;                                                                                                                                                                 ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    '  SetLength(Result.ColorFilter.Colors, Length(Colors));                                                                                                                             ' + LineEnding +
    '  for I := 0 to High(Colors) do                                                                                                                                                     ' + LineEnding +
    '    Result.ColorFilter.Colors[I].Color := Colors[I];                                                                                                                                ' + LineEnding +
    'end;                                                                                                                                                                                ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    'function TOCRInvertColorFilter.Create(Colors, Tolerances: TIntegerArray): TOCRInvertColorFilter; static; overload;                                                                  ' + LineEnding +
    'var                                                                                                                                                                                 ' + LineEnding +
    '  I: Integer;                                                                                                                                                                       ' + LineEnding +
    'begin                                                                                                                                                                               ' + LineEnding +
    '  if Length(Colors) <> Length(Tolerances) then                                                                                                                                      ' + LineEnding +
    '    raise "TOCRInvertColorFilter.Create: Length(Colors) <> Length(Tolerances)";                                                                                                     ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    '  Result.Rule := 4;                                                                                                                                                                 ' + LineEnding +
    '  Result.ColorFilter.Invert := True;                                                                                                                                                ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    '  SetLength(Result.ColorFilter.Colors, Length(Colors));                                                                                                                             ' + LineEnding +
    '  for I := 0 to High(Colors) do                                                                                                                                                     ' + LineEnding +
    '  begin                                                                                                                                                                             ' + LineEnding +
    '    Result.ColorFilter.Colors[I].Color := Colors[I];                                                                                                                                ' + LineEnding +
    '    Result.ColorFilter.Colors[I].Tolerance := Sqr(Tolerances[I]);                                                                                                                   ' + LineEnding +
    '  end;                                                                                                                                                                              ' + LineEnding +
    'end;                                                                                                                                                                                ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    'function TOCRInvertColorFilter.Create(Colors: TIntegerArray): TOCRInvertColorFilter; static; overload;                                                                              ' + LineEnding +
    'var                                                                                                                                                                                 ' + LineEnding +
    '  I: Integer;                                                                                                                                                                       ' + LineEnding +
    'begin                                                                                                                                                                               ' + LineEnding +
    '  Result.Rule := 4;                                                                                                                                                                 ' + LineEnding +
    '  Result.ColorFilter.Invert := True;                                                                                                                                                ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    '  SetLength(Result.ColorFilter.Colors, Length(Colors));                                                                                                                             ' + LineEnding +
    '  for I := 0 to High(Colors) do                                                                                                                                                     ' + LineEnding +
    '    Result.ColorFilter.Colors[I].Color := Colors[I];                                                                                                                                ' + LineEnding +
    'end;                                                                                                                                                                                ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    'function TOCRThresholdFilter.Create(Amount: Integer; Invert: Boolean = False): TOCRThresholdFilter; static;                                                                         ' + LineEnding +
    'begin                                                                                                                                                                               ' + LineEnding +
    '  Result.Rule := 2;                                                                                                                                                                 ' + LineEnding +
    '  Result.ThresholdFilter.Amount := Amount;                                                                                                                                          ' + LineEnding +
    '  Result.ThresholdFilter.Invert := Invert;                                                                                                                                          ' + LineEnding +
    'end;                                                                                                                                                                                ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    'function TOCRShadowFilter.Create(MaxShadowValue: Integer = 25; Tolerance: Integer = 5): TOCRShadowFilter; static;                                                                   ' + LineEnding +
    'begin                                                                                                                                                                               ' + LineEnding +
    '  Result.Rule := 3;                                                                                                                                                                 ' + LineEnding +
    '  Result.ShadowFilter.MaxShadowValue := MaxShadowValue;                                                                                                                             ' + LineEnding +
    '  Result.ShadowFilter.Tolerance := Sqr(Tolerance);                                                                                                                                  ' + LineEnding +
    'end;                                                                                                                                                                                ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    'function TSimpleOCR.Recognize(constref Area: TBox; constref Filter: TOCRFilter; constref Font: TFontSet): String;                                                                   ' + LineEnding +
    'begin                                                                                                                                                                               ' + LineEnding +
    '  Self.Client := GetColorsMatrix(Area.X1, Area.Y1, Area.X2, Area.Y2);                                                                                                               ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    '  Result := Self._Recognize(Filter, Font);                                                                                                                                          ' + LineEnding +
    'end;                                                                                                                                                                                ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    'function TSimpleOCR.RecognizeStatic(constref Area: TBox; constref Filter: TOCRFilter; constref Font: TFontSet; MaxWalk: Integer = 20): String;                             ' + LineEnding +
    'begin                                                                                                                                                                               ' + LineEnding +
    '  Self.Client := GetColorsMatrix(Area.X1, Area.Y1, Area.X2, Area.Y2);                                                                                                               ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    '  Result := Self._RecognizeStatic(Filter, Font, MaxWalk);                                                                                                                           ' + LineEnding +
    'end;                                                                                                                                                                                ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    'function TSimpleOCR.RecognizeLines(constref Area: TBox; constref Filter: TOCRFilter; constref Font: TFontSet; out Bounds: TBoxArray): TStringArray; overload;                       ' + LineEnding +
    'var                                                                                                                                                                                 ' + LineEnding +
    '  I: Integer;                                                                                                                                                                       ' + LineEnding +
    'begin                                                                                                                                                                               ' + LineEnding +
    '  Self.Client := GetColorsMatrix(Area.X1, Area.Y1, Area.X2, Area.Y2);                                                                                                               ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    '  Result := Self._RecognizeLines(Filter, Font, Bounds);                                                                                                                             ' + LineEnding +
    '  for I := 0 to High(Bounds) do                                                                                                                                                     ' + LineEnding +
    '  begin                                                                                                                                                                             ' + LineEnding +
    '    Bounds[I].X1 += Area.X1;                                                                                                                                                        ' + LineEnding +
    '    Bounds[I].Y1 += Area.Y1;                                                                                                                                                        ' + LineEnding +
    '    Bounds[I].X2 += Area.X1;                                                                                                                                                        ' + LineEnding +
    '    Bounds[I].Y2 += Area.Y1;                                                                                                                                                        ' + LineEnding +
    '  end;                                                                                                                                                                              ' + LineEnding +
    'end;                                                                                                                                                                                ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    'function TSimpleOCR.RecognizeLines(constref Area: TBox; constref Filter: TOCRFilter; constref Font: TFontSet): TStringArray; overload;                                              ' + LineEnding +
    'begin                                                                                                                                                                               ' + LineEnding +
    '  Self.Client := GetColorsMatrix(Area.X1, Area.Y1, Area.X2, Area.Y2);                                                                                                               ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    '  Result := Self._RecognizeLines(Filter, Font);                                                                                                                                     ' + LineEnding +
    'end;                                                                                                                                                                                ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    'function TSimpleOCR.RecognizeNumber(constref Area: TBox; constref Filter: TOCRFilter; constref Font: TFontSet): Int64;                                                              ' + LineEnding +
    'var                                                                                                                                                                                 ' + LineEnding +
    '  Text: String;                                                                                                                                                                     ' + LineEnding +
    '  Character: Char;                                                                                                                                                                  ' + LineEnding +
    'begin                                                                                                                                                                               ' + LineEnding +
    '  for Character in Self.Recognize(Area, Filter, Font) do                                                                                                                            ' + LineEnding +
    '    case Character of                                                                                                                                                               ' + LineEnding +
    '      #48..#57: Text += Character;                                                                                                                                                  ' + LineEnding +
    '           #79: Text += #48;                                                                                                                                                        ' + LineEnding +
    '    end;                                                                                                                                                                            ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    '  if (Text <> "") then                                                                                                                                                              ' + LineEnding +
    '    Result := StrToInt(Text);                                                                                                                                                       ' + LineEnding +
    'end;                                                                                                                                                                                ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    'function TSimpleOCR.RecognizeUpText(constref Area: TBox; constref Filter: TOCRFilter; constref Font: TFontSet; MaxWalk: Integer = 20): String;                                         ' + LineEnding +
    'begin                                                                                                                                                                               ' + LineEnding +
    '  Self.Client := GetColorsMatrix(Area.X1, Area.Y1, Area.X2, Area.Y2);                                                                                                               ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    '  Result := Self._RecognizeUpText(Filter, Font, MaxWalk);                                                                                                                           ' + LineEnding +
    'end;                                                                                                                                                                                ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    'function TSimpleOCR.LocateText(constref Area: TBox; Text: String; constref Font: TFontSet; constref Filter: TOCRFilter; out Bounds: TBox): Single; overload;               ' + LineEnding +
    'begin                                                                                                                                                                               ' + LineEnding +
    '  Self.Client := GetColorsMatrix(Area.X1, Area.Y1, Area.X2, Area.Y2);                                                                                                               ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    '  Result := Self._LocateText(Text, Font, Filter, Bounds);                                                                                                                           ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    '  Bounds.X1 += Area.X1;                                                                                                                                                             ' + LineEnding +
    '  Bounds.Y1 += Area.Y1;                                                                                                                                                             ' + LineEnding +
    '  Bounds.X2 += Area.X1;                                                                                                                                                             ' + LineEnding +
    '  Bounds.Y2 += Area.Y1;                                                                                                                                                             ' + LineEnding +
    'end;                                                                                                                                                                                ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    'function TSimpleOCR.LocateText(constref Area: TBox; Text: String; constref Font: TFontSet; out Bounds: TBox): Single; overload;                                            ' + LineEnding +
    'begin                                                                                                                                                                               ' + LineEnding +
    '  Self.Client := GetColorsMatrix(Area.X1, Area.Y1, Area.X2, Area.Y2);                                                                                                               ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    '  Result := Self._LocateText(Text, Font, Bounds);                                                                                                                                   ' + LineEnding +
    '                                                                                                                                                                                    ' + LineEnding +
    '  Bounds.X1 += Area.X1;                                                                                                                                                             ' + LineEnding +
    '  Bounds.Y1 += Area.Y1;                                                                                                                                                             ' + LineEnding +
    '  Bounds.X2 += Area.X1;                                                                                                                                                             ' + LineEnding +
    '  Bounds.Y2 += Area.Y1;                                                                                                                                                             ' + LineEnding +
    'end;'
  );

end.
