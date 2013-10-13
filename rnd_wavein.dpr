program rnd_wavein;

{$APPTYPE CONSOLE}

uses
  Windows,
  MMSystem,
  SysUtils,
  keccak in 'keccak.pas';

type
  TWaveBlock = packed record
    Hdr: TWaveHdr;
    Data: array[0..1000000] of packed record L, R: SmallInt end;
  end;
  PWaveBlock = ^TWaveBlock;

var
  OutFileName: string;
  Size: Int64;
  Raw: Boolean;
  SampNum: Integer;
  BlockSize: Integer;
  Device: string;
  FinishEvent: THandle;
  hWi: THandle;
  OutFile: THandle;
  DeviceId: cardinal;
  Blocks: array of PWaveBlock;
  Sponge: TKeccakExState;
  b, i: integer;
  RndBuf: packed array[0..167] of byte;

procedure StopWithMsg(Msg: string);
begin
  Writeln(ErrOutput, Msg);
  Halt(1);
end;

procedure StopWithHelp;
begin
  StopWithMsg(
    'rnd_wavein <size> <output> [-R] [-S<samples>] [-B<block>] [-D<device>]'#13#10+
    #13#10+
    '<size> is the demanded amount of data in kilobytes.'#13#10+
    '<output> is either filename or * for stdout.'#13#10+
    '-R writes unwhitened raw data. -S and -B ignored.'#13#10+
    '-S sets the number of samples absorbed before squeezing a block.'#13#10+
    '   Default is 256.'#13#10+
    '-B sets the amount of data squeezed at a time, in bytes. Default is 168.'#13#10+
    '-D sets the recording device. <device> can be either #<number> or device name.'#13#10+
    '   #number goes from 0 to the number of available recording devices minus one.'#13#10+
    '   If omitted, the default device is used.'#13#10);
end;

procedure ParseCmdLine;
var
  i: integer;
  Param: string;
begin
  if ParamCount < 2 then StopWithHelp;
  Size := StrToInt64(ParamStr(1))*1024;
  OutFileName := ParamStr(2);

  Raw := false;
  SampNum := 256;
  BlockSize := 168;
  Device := '';
  for i := 3 to ParamCount do begin
    if Length(ParamStr(i)) < 2 then StopWithMsg('Parameter incorrect: '+ParamStr(i));
    Param := Copy(ParamStr(i), 3, MaxInt);
    case UpCase(ParamStr(i)[2]) of
      'R': Raw := true;
      'S': SampNum := StrToInt(Param);
      'B': BlockSize := StrToInt(Param);
      'D': Device := Param;
      else StopWithMsg('Parameter incorrect: '+ParamStr(i));
    end;
  end;

  if (SampNum < 1) or (SampNum > 50000) then
    StopWithMsg('Number of samples not acceptable');
  if (BlockSize < 1) then
    StopWithMsg('Block size not acceptable');
  if Device = '#' then
    StopWithMsg('Recording device not acceptable');
end;

function OpenFile(Name: string): THandle;
begin
  if Name = '*' then
    Result := GetStdHandle(STD_OUTPUT_HANDLE)
  else
    Result := CreateFile(PChar(Name), GENERIC_WRITE,
      FILE_SHARE_READ+FILE_SHARE_WRITE,
      nil, CREATE_NEW, FILE_ATTRIBUTE_NORMAL+FILE_FLAG_SEQUENTIAL_SCAN, 0);

  if Result = INVALID_HANDLE_VALUE then
    StopWithMsg('Open failed ('+IntToStr(integer(GetLastError))+') for '+Name);
end;

function FindDevice(Name: string): cardinal;
var
  i: integer;
  Caps: TWaveInCaps;
  Res: MMRESULT;
begin
  for i := 0 to waveInGetNumDevs - 1 do begin
    Res := waveInGetDevCaps(i, @Caps, SizeOf(Caps));
    if Res <> MMSYSERR_NOERROR then StopWithMsg('waveInGetNumDevs fails: '+IntToStr(Res));

    if Caps.szPname = Name then begin
      Result := i;
      exit;
    end;
  end;
  Result := 0; // false warning
  StopWithMsg('No device with name '+Name);
end;

procedure InitRecording(Device: cardinal);
var
  Fmt: TWaveFormatEx;
  Res: MMRESULT;
begin
  FinishEvent := CreateEvent(nil, false, false, nil);
  if FinishEvent = 0 then StopWithMsg('Can''t create event');

  Fmt.wFormatTag := WAVE_FORMAT_PCM;
  Fmt.nChannels := 2;
  Fmt.nSamplesPerSec := 44100;
  Fmt.wBitsPerSample := 16;
  Fmt.nBlockAlign := Fmt.wBitsPerSample * Fmt.nChannels div 8;
  Fmt.nAvgBytesPerSec := Fmt.nBlockAlign * Fmt.nSamplesPerSec;
  Fmt.cbSize := 0;

  Res := waveInOpen(@hWi, Device, @Fmt, FinishEvent, 0, CALLBACK_EVENT);
  if Res <> MMSYSERR_NOERROR then StopWithMsg('waveInOpen: '+IntToStr(Res));

  Res := waveInStart(hWi);
  if Res <> MMSYSERR_NOERROR then StopWithMsg('waveInStart: '+IntToStr(Res));
end;

function MakeBlock(Samples: integer): PWaveBlock;
begin
  Result := AllocMem(Samples*SizeOf(Smallint) + SizeOf(TWaveHdr));
  Result.Hdr.lpData := @Result.Data;
  Result.Hdr.dwBufferLength := Samples*SizeOf(Smallint);
end;

procedure RecordBlock(Block: PWaveBlock);
var
  Res: MMRESULT;
begin
  Res := waveInPrepareHeader(hWi, @Block.Hdr, SizeOf(Block.Hdr));
  if Res <> MMSYSERR_NOERROR then StopWithMsg('waveInPrepareHeader failed: '+IntToStr(Res));

  Res := waveInAddBuffer(hWi, @Block.Hdr, SizeOf(Block.Hdr));
  if Res <> MMSYSERR_NOERROR then StopWithMsg('waveInAddBuffer failed: '+IntToStr(Res));
end;

procedure WaitBlock(Block: PWaveBlock);
var
  Res: MMRESULT;
  Tick: cardinal;
begin
  Tick := GetTickCount;
  while (Block.Hdr.dwFlags and WHDR_DONE) = 0 do begin
    WaitForSingleObject(FinishEvent, 10);
    if GetTickCount - Tick > 1000 then
      StopWithMsg('Wait timeout on the recording device');
  end;

  Res := waveInUnprepareHeader(hWi, @Block.Hdr, SizeOf(Block.Hdr));
  if Res <> MMSYSERR_NOERROR then StopWithMsg('waveInUnprepareHeader failed: '+IntToStr(Res));
end;

procedure WriteData(F: THandle; const Buf; BufSize: cardinal; var BytesLeft: Int64);
var
  Wrt: cardinal;
begin
  if BytesLeft <= 0 then exit;
  if BufSize > BytesLeft then BufSize := BytesLeft;
  if not WriteFile(F, Buf, BufSize, Wrt, nil) or (Wrt <> BufSize) then
    StopWithMsg('File write error ('+IntToStr(integer(GetLastError))+')');
  BytesLeft := BytesLeft - BufSize;
end;

begin
  ParseCmdLine;

  OutFile := OpenFile(OutFileName);

  if Device = '' then
    DeviceId := WAVE_MAPPER
  else if Device[1] = '#' then
    DeviceId := StrToInt(Copy(Device, 2, MaxInt))
  else
    DeviceId := FindDevice(Device);

  InitRecording(DeviceId);

  KeccakInitExState(Sponge, 168);
  SetLength(Blocks, 8000 div SampNum + 2);
  for b := 0 to High(Blocks) do begin
    Blocks[b] := MakeBlock(SampNum);
    RecordBlock(Blocks[b]);
  end;
  repeat
    for b := 0 to High(Blocks) do begin
      WaitBlock(Blocks[b]);

      if Raw then begin
        WriteData(OutFile, Blocks[b].Data, Blocks[b].Hdr.dwBufferLength, Size);
      end else begin
        KeccakAbsorb(Sponge, Blocks[b].Data, Blocks[b].Hdr.dwBufferLength);
        for i := 0 to BlockSize div 168 - 1 do begin
          KeccakSqueeze(Sponge, RndBuf, 168);
          WriteData(OutFile, RndBuf, 168, Size);
          if Size <= 0 then break;
        end;
        if Size <= 0 then break;
        KeccakSqueeze(Sponge, RndBuf, BlockSize mod 168);
        WriteData(OutFile, RndBuf, BlockSize mod 168, Size);
      end;

      if Size <= 0 then break;

      RecordBlock(Blocks[b]);
    end;
    if Size <= 0 then break;
  until false;

  CloseHandle(OutFile);
end.
