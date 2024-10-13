library SimpleOCR;
{==============================================================================]
  Copyright (c) 2021, Jarl `slacky` Holta
  Project: SimpleOCR
  Project URL: https://github.com/slackydev/SimpleOCR
  License: GNU Lesser GPL (http://www.gnu.org/licenses/lgpl.html)
[==============================================================================}

{$i simpleocr.inc}

uses
  Classes, SysUtils,
  simpleocr.base, simpleocr.engine, simpleocr.filters;

{$i simbaplugin.inc}

type
  PPointArray = ^TPointArray;
  PStringArray = ^TStringArray;
  PIntegerMatrix = ^TIntegerMatrix;

  PSimpleOCR = ^TSimpleOCR;
  PFontSet = ^TFontSet;
  POCRFilter = ^TOCRFilter;
  POCRTarget = ^TOCRTarget;

procedure _LapeFontSet_Create(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PFontSet(Result)^ := TFontSet.Create(PString(Params^[0])^, PInteger(Params^[1])^);
end;

procedure _LapeFontSet_TextToMatrix(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PIntegerMatrix(Result)^ := PFontSet(Params^[0])^.TextToMatrix(PString(Params^[1])^);
end;

procedure _LapeFontSet_TextToTPA(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PPointArray(Result)^ := PFontSet(Params^[0])^.TextToTPA(PString(Params^[1])^);
end;

procedure _LapeSimpleOCR_Locate(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PSingle(Result)^ := PSimpleOCR(Params^[0])^.Locate(POCRTarget(Params^[1])^, PString(Params^[2])^, PFontSet(Params^[3])^, POCRFilter(Params^[4])^);
end;

procedure _LapeSimpleOCR_Recognize(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PString(Result)^ := PSimpleOCR(Params^[0])^.Recognize(POCRTarget(Params^[1])^, POCRFilter(Params^[2])^, PFontSet(Params^[3])^);
end;

procedure _LapeSimpleOCR_RecognizeStatic(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PString(Result)^ := PSimpleOCR(Params^[0])^.RecognizeStatic(POCRTarget(Params^[1])^, POCRFilter(Params^[2])^, PFontSet(Params^[3])^);
end;

procedure _LapeSimpleOCR_RecognizeLines(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PStringArray(Result)^ := PSimpleOCR(Params^[0])^.RecognizeLines(POCRTarget(Params^[1])^, POCRFilter(Params^[2])^, PFontSet(Params^[3])^);
end;

initialization
  addGlobalType(
    'packed record                                   ' + LineEnding +
    '  ImageWidth, ImageHeight: Integer;             ' + LineEnding +
    '  Width, Height: Integer;                       ' + LineEnding +
    '  CharacterBounds: TBox;                        ' + LineEnding +
    '  CharacterPoints: TPointArray;                 ' + LineEnding +
    '  ShadowPoints: TPointArray;                    ' + LineEnding +
    '  BackgroundPoints: TPointArray;                ' + LineEnding +
    '  TotalBounds: TBox;                            ' + LineEnding +
    '  Character: Char;                              ' + LineEnding +
    'end;',
    'TFontGlyph');

  addGlobalType(
    'packed record                                   ' + LineEnding +
    '  Name: String;                                 ' + LineEnding +
    '  SpaceWidth: Integer;                          ' + LineEnding +
    '  Glyphs: array of TFontGlyph;                  ' + LineEnding +
    '  MaxGlyphWidth: Integer;                       ' + LineEnding +
    '  MaxGlyphHeight: Integer;                      ' + LineEnding +
    'end;',
    'TFontSet');


  addGlobalType(
    'packed record                                   ' + LineEnding +
    '  FilterType: Integer;                          ' + LineEnding +
    '                                                ' + LineEnding +
    '  AnyColorFilter: packed record                 ' + LineEnding +
    '    MaxShadowValue: Integer;                    ' + LineEnding +
    '    Tolerance: Single;                          ' + LineEnding +
    '  end;                                          ' + LineEnding +
    '                                                ' + LineEnding +
    '  ColorFilter: packed record                    ' + LineEnding +
    '    Colors: TIntegerArray;                      ' + LineEnding +
    '    Tolerances: TSingleArray;                   ' + LineEnding +
    '    Invert: Boolean;                            ' + LineEnding +
    '  end;                                          ' + LineEnding +
    '                                                ' + LineEnding +
    '  ThresholdFilter: packed record                ' + LineEnding +
    '    Invert: Boolean;                            ' + LineEnding +
    '    C: Integer;                                 ' + LineEnding +
    '  end;                                          ' + LineEnding +
    '                                                ' + LineEnding +
    '  ShadowFilter: packed record                   ' + LineEnding +
    '    MaxShadowValue: Integer;                    ' + LineEnding +
    '    Tolerance: Single;                          ' + LineEnding +
    '  end;                                          ' + LineEnding +
    '                                                ' + LineEnding +
    '  Blacklist: String;                            ' + LineEnding +
    'end;',
    'TOCRFilter');

  addGlobalType(
    'packed record                ' + LineEnding +
    '  Text: String;       ' + LineEnding +
    '  Bounds: TBox;       ' + LineEnding +
    '  Hits: Integer;      ' + LineEnding +
    'end;',
    'TOCRMatch');

  addGlobalType('TIntegerMatrix', 'TOCRTarget');

  addGlobalType(
    'packed record                                                                    ' + LineEnding +
    '  Client: TIntegerMatrix;                                                        ' + LineEnding +
    '  Matches: array of TOCRMatch;                                                   ' + LineEnding +
    '  Offset: TPoint;                                                                ' + LineEnding +
    '  {%CODETOOLS OFF}                                                               ' + LineEnding +
    '  InternalData: array[1..' + IntToStr(TSimpleOCR.InternalDataSize) + '] of Byte; ' + LineEnding +
    '  {%CODETOOLS ON}                                                                ' + LineEnding +
    'end;',
    'TSimpleOCR');

  addGlobalFunc('function TFontSet.Create(Directory: String; SpaceWidth: Integer = 4): TFontSet; static; native;', @_LapeFontSet_Create);
  addGlobalFunc('function TFontSet.TextToMatrix(Text: String): TIntegerMatrix; native;', @_LapeFontSet_TextToMatrix);
  addGlobalFunc('function TFontSet.TextToTPA(Text: String): TPointArray; native;', @_LapeFontSet_TextToTPA);

  addGlobalFunc('function TSimpleOCR.Recognize(Target: TOCRTarget; Filter: TOCRFilter; Font: TFontSet): String; native;', @_LapeSimpleOCR_Recognize);
  addGlobalFunc('function TSimpleOCR.RecognizeLines(Target: TOCRTarget; Filter: TOCRFilter; Font: TFontSet): TStringArray; native;', @_LapeSimpleOCR_RecognizeLines);
  addGlobalFunc('function TSimpleOCR.RecognizeStatic(Target: TOCRTarget; Filter: TOCRFilter; Font: TFontSet): String; native;', @_LapeSimpleOCR_RecognizeStatic);

  addGlobalFunc('function TSimpleOCR.Locate(Target: TOCRTarget; Text: String; Font: TFontSet; Filter: TOCRFilter): Single; native;', @_LapeSimpleOCR_Locate);

  addCode([
    '{$IFDEF SIMPLEOCR_CHECK_SIZES}',
    Format('begin if SizeOf(%s) <> %d then raise "%s wrong size"; end;', ['TSimpleOCR', SizeOf(TSimpleOCR), 'TSimpleOCR']),
    Format('begin if SizeOf(%s) <> %d then raise "%s wrong size"; end;', ['TOCRFilter', SizeOf(TOCRFilter), 'TOCRFilter']),
    Format('begin if SizeOf(%s) <> %d then raise "%s wrong size"; end;', ['TOCRMatch',  SizeOf(TOCRMatch),  'TOCRMatch']),
    Format('begin if SizeOf(%s) <> %d then raise "%s wrong size"; end;', ['TFontSet',   SizeOf(TFontSet),   'TFontSet']),
    Format('begin if SizeOf(%s) <> %d then raise "%s wrong size"; end;', ['TFontGlyph', SizeOf(TFontGlyph), 'TFontGlyph']),
    '{$ENDIF}',
    '',
    '{%CODETOOLS OFF}',
    'function TSimpleOCR._GetColorsMatrix(B: TBox): TIntegerMatrix; static;',
    'begin',
    '  {$IFDEF SIMBAMAJOR2000}',
    '  Result := Target.GetColorsMatrix(B);',
    '  {$ELSE}',
    '  Result := GetColorsMatrix(B.X1, B.Y1, B.X2, B.Y2);',
    '  {$ENDIF}',
    'end;',
    '{%CODETOOLS ON}',
    '',
    'type TOCRAnyColorFilter    = type TOCRFilter; // 0',
    'type TOCRColorFilter       = type TOCRFilter; // 1',
    'type TOCRThresholdFilter   = type TOCRFilter; // 2',
    'type TOCRShadowFilter      = type TOCRFilter; // 3',
    'type TOCRInvertColorFilter = type TOCRFilter; // 4',
    '',
    'function TOCRAnyColorFilter.Create(Tolerance: Single; MaxShadowValue: Integer = 0): TOCRAnyColorFilter; static;',
    'begin',
    '  Result.FilterType := 0;',
    '  Result.AnyColorFilter.Tolerance := Tolerance;',
    '  Result.AnyColorFilter.MaxShadowValue := MaxShadowValue;',
    'end;',
    '',
    'function TOCRColorFilter.Create(Colors: TColorArray; Tolerances: TSingleArray): TOCRColorFilter; static; overload;',
    'var',
    '  I: Integer;',
    'begin',
    '  if Length(Colors) <> Length(Tolerances) then',
    '    raise "TOCRColorFilter.Create: Length(Colors) <> Length(Tolerances)";',
    '',
    '  Result.FilterType := 1;',
    '  Result.ColorFilter.Colors := TIntegerArray(Colors);',
    '  Result.ColorFilter.Tolerances := Tolerances;',
    'end;',
    '',
    'function TOCRColorFilter.Create(Colors: TColorArray): TOCRColorFilter; static; overload;',
    'begin',
    '  Result.FilterType := 1;',
    '  Result.ColorFilter.Colors := TIntegerArray(Colors);',
    '  SetLength(Result.ColorFilter.Tolerances, Length(Colors));',
    'end;',
    '',
    'function TOCRInvertColorFilter.Create(Colors: TColorArray; Tolerances: TSingleArray): TOCRInvertColorFilter; static; overload;',
    'var',
    '  I: Integer;',
    'begin',
    '  if Length(Colors) <> Length(Tolerances) then',
    '    raise "TOCRInvertColorFilter.Create: Length(Colors) <> Length(Tolerances)";',
    '',
    '  Result.FilterType := 4;',
    '  Result.ColorFilter.Invert := True;',
    '  Result.ColorFilter.Colors := TIntegerArray(Colors);',
    '  Result.ColorFilter.Tolerances := Tolerances;',
    'end;',
    '',
    'function TOCRInvertColorFilter.Create(Colors: TColorArray): TOCRInvertColorFilter; static; overload;',
    'var',
    '  I: Integer;',
    'begin',
    '  Result.FilterType := 4;',
    '  Result.ColorFilter.Invert := True;',
    '  Result.ColorFilter.Colors := TIntegerArray(Colors);',
    '  SetLength(Result.ColorFilter.Tolerances, Length(Colors));',
    'end;',
    '',
    'function TOCRThresholdFilter.Create(Invert: Boolean = False; C: Integer = 0): TOCRThresholdFilter; static;',
    'begin',
    '  Result.FilterType := 2;',
    '  Result.ThresholdFilter.Invert := Invert;',
    '  Result.ThresholdFilter.C := C;',
    'end;',
    '',
    'function TOCRShadowFilter.Create(MaxShadowValue: Integer = 25; Tolerance: Single = 5): TOCRShadowFilter; static;',
    'begin',
    '  Result.FilterType := 3;',
    '  Result.ShadowFilter.MaxShadowValue := MaxShadowValue;',
    '  Result.ShadowFilter.Tolerance := Tolerance;',
    'end;',
    '',
    'function TSimpleOCR.Recognize(Area: TBox; Filter: TOCRFilter; constref Font: TFontSet): String; overload;',
    'begin',
    '  Self.Offset := [Area.X1, Area.Y1];',
    '',
    '  Result := Self.Recognize(TSimpleOCR._GetColorsMatrix(Area), Filter, Font);',
    'end;',
    '',
    'function TSimpleOCR.RecognizeStatic(Area: TBox; Filter: TOCRFilter; constref Font: TFontSet): String; overload;',
    'begin',
    '  Self.Offset := [Area.X1, Area.Y1];',
    '',
    '  Result := Self.RecognizeStatic(TSimpleOCR._GetColorsMatrix(Area), Filter, Font);',
    'end;',
    '',
    'function TSimpleOCR.RecognizeLines(Area: TBox; Filter: TOCRFilter; constref Font: TFontSet): TStringArray; overload;',
    'begin',
    '  Self.Offset := [Area.X1, Area.Y1];',
    '',
    '  Result := Self.RecognizeLines(TSimpleOCR._GetColorsMatrix(Area), Filter, Font);',
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
    '    Result := StrToInt64(Text);',
    'end;',
    '',
    'function TSimpleOCR.Locate(Area: TBox; Text: String; constref Font: TFontSet; Filter: TOCRFilter): Single; overload;',
    'begin',
    '  Self.Offset := [Area.X1, Area.Y1];',
    '',
    '  Result := Self.Locate(TSimpleOCR._GetColorsMatrix(Area), Text, Font, Filter);',
    'end;'
  ]);

end.
