{$mode objfpc}{$H+}

{$modeswitch advancedrecords}
{$modeswitch arrayoperators}

{$scopedenums on}

{$IFOPT D-} // No debug info = enable max optimization
  {$OPTIMIZATION LEVEL4}

  {$OPTIMIZATION noORDERFIELDS} // need same field ordering in script
  {$OPTIMIZATION noDEADSTORE}   // buggy as of FPC .2.2
{$ENDIF}
