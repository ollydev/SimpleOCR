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
  simpleocr.types, simpleocr.engine, simpleocr.filters;

{$i simbaplugin.inc}

procedure TFontSet_Load(const Params: PParamArray); cdecl;
begin
  PFontSet(Params^[0])^.Load(PString(Params^[1])^, PInteger(Params^[2])^);
end;

procedure TSimpleOCR_TextToMatrix(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PIntegerMatrix(Result)^ := PSimpleOCR(Params^[0])^.TextToMatrix(PString(Params^[1])^, PFontSet(Params^[2])^);
end;

procedure TSimpleOCR_TextToTPA(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PPointArray(Result)^ := PSimpleOCR(Params^[0])^.TextToTPA(PString(Params^[1])^, PFontSet(Params^[2])^);
end;

procedure TSimpleOCR_LocateText1(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PSingle(Result)^ := PSimpleOCR(Params^[0])^.LocateText(PIntegerMatrix(Params^[1])^, PString(Params^[2])^, PFontSet(Params^[3])^, POCRFilter(Params^[4])^, PBox(Params^[5])^);
end;

procedure TSimpleOCR_LocateText2(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PBoolean(Result)^ := PSimpleOCR(Params^[0])^.LocateText(PIntegerMatrix(Params^[1])^, PString(Params^[2])^, PFontSet(Params^[3])^, POCRFilter(Params^[4])^, PSingle(Params^[5])^);
end;

procedure TSimpleOCR_Recognize(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PString(Result)^ := PSimpleOCR(Params^[0])^.Recognize(PIntegerMatrix(Params^[1])^, POCRFilter(Params^[2])^, PFontSet(Params^[3])^);
end;

procedure TSimpleOCR_RecognizeStatic(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PString(Result)^ := PSimpleOCR(Params^[0])^.RecognizeStatic(PIntegerMatrix(Params^[1])^, POCRFilter(Params^[2])^, PFontSet(Params^[3])^, PInteger(Params^[4])^);
end;

procedure TSimpleOCR_RecognizeLines(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PStringArray(Result)^ := PSimpleOCR(Params^[0])^.RecognizeLines(PIntegerMatrix(Params^[1])^, POCRFilter(Params^[2])^, PFontSet(Params^[3])^, PBoxArray(Params^[4])^);
end;

procedure TSimpleOCR_RecognizeLinesEx(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PStringArray(Result)^ := PSimpleOCR(Params^[0])^.RecognizeLines(PIntegerMatrix(Params^[1])^, POCRFilter(Params^[2])^, PFontSet(Params^[3])^);
end;

var
  InternalDataSize: Integer;

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
    '  AnyColorFilter: packed record                 ' + LineEnding +
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

  InternalDataSize := SizeOf(TSimpleOCR) - (SizeOf(TFontSet) + SizeOf(TIntegerMatrix));

  addGlobalType(
    'packed record                                                        ' + LineEnding +
    '  FontSet: TFontSet;                                                 ' + LineEnding +
    '  Client: TIntegerMatrix;                                           ' + LineEnding +
    '  InternalData: array[1..' + IntToStr(InternalDataSize) + '] of Byte;' + LineEnding +
    'end;',
    'TSimpleOCR');

  addGlobalFunc('procedure TFontSet.Load(FileName: String; Space: Integer = 4); native;', @TFontSet_Load);

  addGlobalFunc('function TSimpleOCR.TextToMatrix(Text: String; constref Font: TFontSet): TIntegerMatrix; native;', @TSimpleOCR_TextToMatrix);
  addGlobalFunc('function TSimpleOCR.TextToTPA(Text: String; constref Font: TFontSet): TPointArray; native;', @TSimpleOCR_TextToTPA);

  addGlobalFunc('function TSimpleOCR._LocateText(Matrix: TIntegerMatrix; Text: String; constref Font: TFontSet; Filter: TOCRFilter; out Bounds: TBox): Single; overload; native;', @TSimpleOCR_LocateText1);
  addGlobalFunc('function TSimpleOCR._LocateText(Matrix: TIntegerMatrix; Text: String; constref Font: TFontSet; Filter: TOCRFilter; MinMatch: Single = 1): Boolean; overload; native;', @TSimpleOCR_LocateText2);

  addGlobalFunc('function TSimpleOCR._Recognize(Matrix: TIntegerMatrix; Filter: TOCRFilter; constref Font: TFontSet): String; native;', @TSimpleOCR_Recognize);
  addGlobalFunc('function TSimpleOCR._RecognizeLines(Matrix: TIntegerMatrix; Filter: TOCRFilter; constref Font: TFontSet; out Bounds: TBoxArray): TStringArray; overload; native;', @TSimpleOCR_RecognizeLines);
  addGlobalFunc('function TSimpleOCR._RecognizeLines(Matrix: TIntegerMatrix; Filter: TOCRFilter; constref Font: TFontSet): TStringArray; overload; native;', @TSimpleOCR_RecognizeLinesEx);
  addGlobalFunc('function TSimpleOCR._RecognizeStatic(Matrix: TIntegerMatrix; Filter: TOCRFilter; constref Font: TFontSet; MaxWalk: Integer = 20): String; native;', @TSimpleOCR_RecognizeStatic);

  addCode([
    'function TSimpleOCR._GetColorsMatrix(B: TBox): TIntegerMatrix; static;',
    'begin',
    '  {$IFDEF SIMBAMAJOR2000}',
    '  Result := Finder.GetColorsMatrix(B);',
    '  {$ELSE}',
    '  Result := GetColorsMatrix(B.X1, B.Y1, B.X2, B.Y2);',
    '  {$ENDIF}',
    'end;',
    '',
    'type TOCRAnyColorFilter    = type TOCRFilter; // 0',
    'type TOCRColorFilter       = type TOCRFilter; // 1',
    'type TOCRThresholdFilter   = type TOCRFilter; // 2',
    'type TOCRShadowFilter      = type TOCRFilter; // 3',
    'type TOCRInvertColorFilter = type TOCRFilter; // 4',
    '',
    'function TOCRAnyColorFilter.Create(Tolerance: Integer; MaxShadowValue: Integer): TOCRAnyColorFilter; static;',
    'begin',
    '  Result.Rule := 0;',
    '  Result.AnyColorFilter.Tolerance := Tolerance;',
    '  Result.AnyColorFilter.MaxShadowValue := MaxShadowValue;',
    'end;',
    '',
    'function TOCRColorFilter.Create(Colors, Tolerances: TIntegerArray): TOCRColorFilter; static; overload;',
    'var',
    '  I: Integer;',
    'begin',
    '  if Length(Colors) <> Length(Tolerances) then',
    '    raise "TOCRColorFilter.Create: Length(Colors) <> Length(Tolerances)";',
    '',
    '  Result.Rule := 1;',
    '',
    '  SetLength(Result.ColorFilter.Colors, Length(Colors));',
    '  for I := 0 to High(Colors) do',
    '  begin',
    '    Result.ColorFilter.Colors[I].Color := Colors[I];',
    '    Result.ColorFilter.Colors[I].Tolerance := Tolerances[I];',
    '  end;',
    'end;',
    '',
    'function TOCRColorFilter.Create(Colors: TIntegerArray): TOCRColorFilter; static; overload;',
    'var',
    '  I: Integer;',
    'begin',
    '  Result.Rule := 1;',
    '',
    '  SetLength(Result.ColorFilter.Colors, Length(Colors));',
    '  for I := 0 to High(Colors) do',
    '    Result.ColorFilter.Colors[I].Color := Colors[I];',
    'end;',
    '',
    'function TOCRInvertColorFilter.Create(Colors, Tolerances: TIntegerArray): TOCRInvertColorFilter; static; overload;',
    'var',
    '  I: Integer;',
    'begin',
    '  if Length(Colors) <> Length(Tolerances) then',
    '    raise "TOCRInvertColorFilter.Create: Length(Colors) <> Length(Tolerances)";',
    '',
    '  Result.Rule := 4;',
    '  Result.ColorFilter.Invert := True;',
    '',
    '  SetLength(Result.ColorFilter.Colors, Length(Colors));',
    '  for I := 0 to High(Colors) do',
    '  begin',
    '    Result.ColorFilter.Colors[I].Color := Colors[I];',
    '    Result.ColorFilter.Colors[I].Tolerance := Tolerances[I];',
    '  end;',
    'end;',
    '',
    'function TOCRInvertColorFilter.Create(Colors: TIntegerArray): TOCRInvertColorFilter; static; overload;',
    'var',
    '  I: Integer;',
    'begin',
    '  Result.Rule := 4;',
    '  Result.ColorFilter.Invert := True;',
    '',
    '  SetLength(Result.ColorFilter.Colors, Length(Colors));',
    '  for I := 0 to High(Colors) do',
    '    Result.ColorFilter.Colors[I].Color := Colors[I];',
    'end;',
    '',
    'function TOCRThresholdFilter.Create(Amount: Integer; Invert: Boolean = False): TOCRThresholdFilter; static;',
    'begin',
    '  Result.Rule := 2;',
    '  Result.ThresholdFilter.Amount := Amount;',
    '  Result.ThresholdFilter.Invert := Invert;',
    'end;',
    '',
    'function TOCRShadowFilter.Create(MaxShadowValue: Integer = 25; Tolerance: Integer = 5): TOCRShadowFilter; static;',
    'begin',
    '  Result.Rule := 3;',
    '  Result.ShadowFilter.MaxShadowValue := MaxShadowValue;',
    '  Result.ShadowFilter.Tolerance := Tolerance;',
    'end;',
    '',
    'function TSimpleOCR.Recognize(Area: TBox; Filter: TOCRFilter; constref Font: TFontSet): String;',
    'begin',
    '  Result := Self._Recognize(TSimpleOCR._GetColorsMatrix(Area), Filter, Font);',
    'end;',
    '',
    'function TSimpleOCR.RecognizeStatic(Area: TBox; Filter: TOCRFilter; constref Font: TFontSet; MaxWalk: Integer = 20): String;',
    'begin',
    '  Result := Self._RecognizeStatic(TSimpleOCR._GetColorsMatrix(Area), Filter, Font, MaxWalk);',
    'end;',
    '',
    'function TSimpleOCR.RecognizeLines(Area: TBox; Filter: TOCRFilter; constref Font: TFontSet; out Bounds: TBoxArray): TStringArray; overload;',
    'var',
    '  I: Integer;',
    'begin',
    '  Result := Self._RecognizeLines(TSimpleOCR._GetColorsMatrix(Area), Filter, Font, Bounds);',
    '  for I := 0 to High(Bounds) do',
    '  begin',
    '    Bounds[I].X1 += Area.X1;',
    '    Bounds[I].Y1 += Area.Y1;',
    '    Bounds[I].X2 += Area.X1;',
    '    Bounds[I].Y2 += Area.Y1;',
    '  end;',
    'end;',
    '',
    'function TSimpleOCR.RecognizeLines(Area: TBox; Filter: TOCRFilter; constref Font: TFontSet): TStringArray; overload;',
    'begin',
    '  Result := Self._RecognizeLines(TSimpleOCR._GetColorsMatrix(Area), Filter, Font);',
    'end;',
    '',
    'function TSimpleOCR.RecognizeNumber(Area: TBox; Filter: TOCRFilter; constref Font: TFontSet): Int64;',
    'var',
    '  Text: String;',
    '  Character: Char;',
    'begin',
    '  for Character in Self.Recognize(Area, Filter, Font) do',
    '    case Character of',
    '      #48..#57: Text += Character;',
    '           #79: Text += #48;',
    '    end;',
    '',
    '  if (Text <> "") then',
    '    Result := StrToInt(Text);',
    'end;',
    '',
    'function TSimpleOCR.LocateText(Area: TBox; Text: String; constref Font: TFontSet; Filter: TOCRFilter; out Bounds: TBox): Single; overload;',
    'begin',
    '  Result := Self._LocateText(TSimpleOCR._GetColorsMatrix(Area), Text, Font, Filter, Bounds);',
    '',
    '  Bounds.X1 += Area.X1;',
    '  Bounds.Y1 += Area.Y1;',
    '  Bounds.X2 += Area.X1;',
    '  Bounds.Y2 += Area.Y1;',
    'end;',
    '',
    'function TSimpleOCR.LocateText(Area: TBox; Text: String; constref Font: TFontSet; Filter: TOCRFilter; MinMatch: Single): Boolean; overload;',
    'begin',
    '  Result := Self._LocateText(TSimpleOCR._GetColorsMatrix(Area), Text, Font, Filter, MinMatch);',
    'end;'
  ]);

end.
