unit keccak;

interface

{$R-,Q-,O+}

type
  TKeccakState = array[0..4, 0..4] of Int64; // beware! y,x order!
  TKeccakStateBytes = packed array[0..199] of byte; // you can cast TKeccakState to this
  TKeccakExState = record
    A: TKeccakState;
    ip: integer;
    op: integer;
    r: integer; // in bytes
  end;

procedure KeccakInitExState(out State: TKeccakExState; r: integer = 1344 div 8); // r in bytes
procedure KeccakAbsorb(var State: TKeccakExState; const Data; Size: integer);
procedure KeccakSqueeze(var State: TKeccakExState; out Data; Size: integer);


implementation


procedure KeccakInitState(out A: TKeccakState);
begin
  Fillchar(A, SizeOf(A), 0);
end;

procedure KeccakRound(var A: TKeccakState; RC: Int64);
var
  C0, C1, C2, C3, C4: Int64;
  D: Int64;
  B: array[0..4, 0..4] of Int64;
begin
  // theta step
  C0 := A[0, 0] xor A[1, 0] xor A[2, 0] xor A[3, 0] xor A[4, 0];
  C1 := A[0, 1] xor A[1, 1] xor A[2, 1] xor A[3, 1] xor A[4, 1];
  C2 := A[0, 2] xor A[1, 2] xor A[2, 2] xor A[3, 2] xor A[4, 2];
  C3 := A[0, 3] xor A[1, 3] xor A[2, 3] xor A[3, 3] xor A[4, 3];
  C4 := A[0, 4] xor A[1, 4] xor A[2, 4] xor A[3, 4] xor A[4, 4];

  D := C4 xor (C1 shl 1 OR C1 shr 63);
  A[0, 0] := A[0, 0] xor D;
  A[1, 0] := A[1, 0] xor D;
  A[2, 0] := A[2, 0] xor D;
  A[3, 0] := A[3, 0] xor D;
  A[4, 0] := A[4, 0] xor D;

  D := C0 xor (C2 shl 1 OR C2 shr 63);
  A[0, 1] := A[0, 1] xor D;
  A[1, 1] := A[1, 1] xor D;
  A[2, 1] := A[2, 1] xor D;
  A[3, 1] := A[3, 1] xor D;
  A[4, 1] := A[4, 1] xor D;

  D := C1 xor (C3 shl 1 OR C3 shr 63);
  A[0, 2] := A[0, 2] xor D;
  A[1, 2] := A[1, 2] xor D;
  A[2, 2] := A[2, 2] xor D;
  A[3, 2] := A[3, 2] xor D;
  A[4, 2] := A[4, 2] xor D;

  D := C2 xor (C4 shl 1 OR C4 shr 63);
  A[0, 3] := A[0, 3] xor D;
  A[1, 3] := A[1, 3] xor D;
  A[2, 3] := A[2, 3] xor D;
  A[3, 3] := A[3, 3] xor D;
  A[4, 3] := A[4, 3] xor D;

  D := C3 xor (C0 shl 1 OR C0 shr 63);
  A[0, 4] := A[0, 4] xor D;
  A[1, 4] := A[1, 4] xor D;
  A[2, 4] := A[2, 4] xor D;
  A[3, 4] := A[3, 4] xor D;
  A[4, 4] := A[4, 4] xor D;

  // rho and pi and ksi steps
  // B[0, 0] = A[0, 0]
  B[1, 0] := A[1, 1] shl 44  OR  A[1, 1] shr 20;
  B[2, 0] := A[2, 2] shl 43  OR  A[2, 2] shr 21;
  B[3, 0] := A[3, 3] shl 21  OR  A[3, 3] shr 43;
  B[4, 0] := A[4, 4] shl 14  OR  A[4, 4] shr 50;
  B[0, 1] := A[0, 3] shl 28  OR  A[0, 3] shr 36;
  B[1, 1] := A[1, 4] shl 20  OR  A[1, 4] shr 44;
  B[2, 1] := A[2, 0] shl  3  OR  A[2, 0] shr 61;
  B[3, 1] := A[3, 1] shl 45  OR  A[3, 1] shr 19;
  B[4, 1] := A[4, 2] shl 61  OR  A[4, 2] shr  3;
  B[0, 2] := A[0, 1] shl  1  OR  A[0, 1] shr 63;
  B[1, 2] := A[1, 2] shl  6  OR  A[1, 2] shr 58;
  B[2, 2] := A[2, 3] shl 25  OR  A[2, 3] shr 39;
  B[3, 2] := A[3, 4] shl  8  OR  A[3, 4] shr 56;
  B[4, 2] := A[4, 0] shl 18  OR  A[4, 0] shr 46;
  B[0, 3] := A[0, 4] shl 27  OR  A[0, 4] shr 37;
  B[1, 3] := A[1, 0] shl 36  OR  A[1, 0] shr 28;
  B[2, 3] := A[2, 1] shl 10  OR  A[2, 1] shr 54;
  B[3, 3] := A[3, 2] shl 15  OR  A[3, 2] shr 49;
  B[4, 3] := A[4, 3] shl 56  OR  A[4, 3] shr  8;
  B[0, 4] := A[0, 2] shl 62  OR  A[0, 2] shr  2;
  B[1, 4] := A[1, 3] shl 55  OR  A[1, 3] shr  9;
  B[2, 4] := A[2, 4] shl 39  OR  A[2, 4] shr 25;
  B[3, 4] := A[3, 0] shl 41  OR  A[3, 0] shr 23;
  B[4, 4] := A[4, 1] shl  2  OR  A[4, 1] shr 62;

  A[0, 1] := B[1, 0] xor (not B[2, 0] and B[3, 0]);
  A[0, 2] := B[2, 0] xor (not B[3, 0] and B[4, 0]);
  A[0, 3] := B[3, 0] xor (not B[4, 0] and A[0, 0]); // ! A
  A[0, 4] := B[4, 0] xor (not A[0, 0] and B[1, 0]); // ! A
  A[1, 0] := B[0, 1] xor (not B[1, 1] and B[2, 1]);
  A[1, 1] := B[1, 1] xor (not B[2, 1] and B[3, 1]);
  A[1, 2] := B[2, 1] xor (not B[3, 1] and B[4, 1]);
  A[1, 3] := B[3, 1] xor (not B[4, 1] and B[0, 1]);
  A[1, 4] := B[4, 1] xor (not B[0, 1] and B[1, 1]);
  A[2, 0] := B[0, 2] xor (not B[1, 2] and B[2, 2]);
  A[2, 1] := B[1, 2] xor (not B[2, 2] and B[3, 2]);
  A[2, 2] := B[2, 2] xor (not B[3, 2] and B[4, 2]);
  A[2, 3] := B[3, 2] xor (not B[4, 2] and B[0, 2]);
  A[2, 4] := B[4, 2] xor (not B[0, 2] and B[1, 2]);
  A[3, 0] := B[0, 3] xor (not B[1, 3] and B[2, 3]);
  A[3, 1] := B[1, 3] xor (not B[2, 3] and B[3, 3]);
  A[3, 2] := B[2, 3] xor (not B[3, 3] and B[4, 3]);
  A[3, 3] := B[3, 3] xor (not B[4, 3] and B[0, 3]);
  A[3, 4] := B[4, 3] xor (not B[0, 3] and B[1, 3]);
  A[4, 0] := B[0, 4] xor (not B[1, 4] and B[2, 4]);
  A[4, 1] := B[1, 4] xor (not B[2, 4] and B[3, 4]);
  A[4, 2] := B[2, 4] xor (not B[3, 4] and B[4, 4]);
  A[4, 3] := B[3, 4] xor (not B[4, 4] and B[0, 4]);
  A[4, 4] := B[4, 4] xor (not B[0, 4] and B[1, 4]);
  A[0, 0] := A[0, 0] xor (not B[1, 0] and B[2, 0]); // ! A

  // iota step
  A[0, 0] := A[0, 0] xor RC;
end;

const RoundConstants: array[0..254] of Int64 = (
  $0000000000000001,
  $0000000000008082,
  $800000000000808A,
  $8000000080008000,
  $000000000000808B,
  $0000000080000001,
  $8000000080008081,
  $8000000000008009,
  $000000000000008A,
  $0000000000000088,
  $0000000080008009,
  $000000008000000A,
  $000000008000808B,
  $800000000000008B,
  $8000000000008089,
  $8000000000008003,
  $8000000000008002,
  $8000000000000080,
  $000000000000800A,
  $800000008000000A,
  $8000000080008081,
  $8000000000008080,
  $0000000080000001,
  $8000000080008008,
  $8000000080008082,
  $800000008000800A,
  $8000000000000003,
  $8000000080000009,
  $8000000000008082,
  $0000000000008009,
  $8000000000000080,
  $0000000000008083,
  $8000000000000081,
  $0000000000000001,
  $000000000000800B,
  $8000000080008001,
  $0000000000000080,
  $8000000000008000,
  $8000000080008001,
  $0000000000000009,
  $800000008000808B,
  $0000000000000081,
  $8000000000000082,
  $000000008000008B,
  $8000000080008009,
  $8000000080000000,
  $0000000080000080,
  $0000000080008003,
  $8000000080008082,
  $8000000080008083,
  $8000000080000088,
  $0000000000008089,
  $0000000000008009,
  $8000000000000009,
  $0000000080008008,
  $0000000080008001,
  $800000000000008A,
  $800000000000000B,
  $0000000000000089,
  $0000000080000002,
  $800000000000800B,
  $000000008000800B,
  $000000000000808B,
  $0000000080000088,
  $800000000000800A,
  $0000000080000089,
  $8000000000000001,
  $8000000000008088,
  $8000000000000081,
  $0000000000000088,
  $0000000080008080,
  $0000000000000081,
  $800000000000000B,
  $0000000000000000,
  $0000000000000089,
  $000000008000008B,
  $8000000080008080,
  $800000000000008B,
  $8000000000008000,
  $8000000080008088,
  $0000000080000082,
  $000000000000000B,
  $800000000000000A,
  $0000000000008082,
  $8000000000008003,
  $800000000000808B,
  $800000008000000B,
  $800000008000008A,
  $0000000080000081,
  $0000000080000081,
  $0000000080000008,
  $0000000000000083,
  $8000000080008003,
  $0000000080008088,
  $8000000080000088,
  $0000000000008000,
  $0000000080008082,
  $0000000080008089,
  $8000000080008083,
  $8000000080000001,
  $0000000080008002,
  $8000000080000089,
  $0000000000000082,
  $8000000080000008,
  $8000000000000089,
  $8000000080000008,
  $8000000000000000,
  $8000000000000083,
  $0000000080008080,
  $0000000000000008,
  $8000000080000080,
  $8000000080008080,
  $8000000000000002,
  $800000008000808B,
  $0000000000000008,
  $8000000080000009,
  $800000000000800B,
  $0000000080008082,
  $0000000080008000,
  $8000000000008008,
  $0000000000008081,
  $8000000080008089,
  $0000000080008089,
  $800000008000800A,
  $800000000000008A,
  $8000000000000082,
  $0000000080000002,
  $8000000000008082,
  $0000000000008080,
  $800000008000000B,
  $8000000080000003,
  $000000000000000A,
  $8000000000008001,
  $8000000080000083,
  $8000000000008083,
  $000000000000008B,
  $000000000000800A,
  $8000000080000083,
  $800000000000800A,
  $0000000080000000,
  $800000008000008A,
  $0000000080000008,
  $000000000000000A,
  $8000000000008088,
  $8000000000000008,
  $0000000080000003,
  $8000000000000000,
  $800000000000000A,
  $000000000000800B,
  $8000000080008088,
  $000000008000000B,
  $0000000080000080,
  $000000008000808A,
  $8000000000008009,
  $0000000000000003,
  $0000000080000003,
  $8000000000000089,
  $8000000080000081,
  $800000008000008B,
  $0000000080008003,
  $800000008000800B,
  $8000000000008008,
  $0000000000008008,
  $8000000000008002,
  $8000000000000009,
  $0000000080008081,
  $000000000000808A,
  $000000008000800A,
  $0000000000000080,
  $8000000000008089,
  $800000000000808A,
  $8000000080008089,
  $0000000080008000,
  $8000000000008081,
  $000000008000800A,
  $0000000000000009,
  $8000000080008002,
  $000000008000000A,
  $0000000080008002,
  $8000000080000000,
  $0000000080000009,
  $0000000000008088,
  $0000000000000002,
  $0000000080008008,
  $0000000080008088,
  $8000000080000001,
  $000000008000808B,
  $8000000000000002,
  $8000000080008002,
  $0000000080000083,
  $0000000000008089,
  $0000000000008080,
  $8000000080000082,
  $8000000000000088,
  $800000008000808A,
  $000000000000808A,
  $0000000080008083,
  $000000008000000B,
  $0000000080000009,
  $0000000000008001,
  $0000000080000089,
  $8000000000000088,
  $8000000080008003,
  $0000000080008001,
  $8000000000000003,
  $8000000080000080,
  $8000000080008009,
  $8000000080000089,
  $000000000000000B,
  $8000000000000083,
  $0000000080008009,
  $0000000080000083,
  $0000000000008000,
  $000000008000800B,
  $0000000000008002,
  $0000000000000003,
  $000000008000008A,
  $8000000080000002,
  $0000000000008001,
  $0000000080000000,
  $8000000080000003,
  $0000000000000083,
  $800000008000808A,
  $0000000000008003,
  $0000000000008008,
  $800000000000808B,
  $8000000080000082,
  $8000000000000001,
  $8000000000008001,
  $800000008000000A,
  $8000000080008008,
  $800000008000800B,
  $8000000000008081,
  $0000000080008083,
  $0000000080000082,
  $0000000000000082,
  $8000000080000081,
  $8000000080000002,
  $0000000000008088,
  $000000000000008B,
  $0000000000008083,
  $8000000000000008,
  $000000008000008A,
  $800000008000008B,
  $000000008000808A,
  $8000000000008080,
  $0000000080000088,
  $8000000000008083,
  $0000000000000002,
  $0000000080008081,
  $0000000000008003,
  $0000000000008081,
  $8000000080008000,
  $0000000000008002,
  $000000000000008A);

procedure KeccakF(var A: TKeccakState; Rounds: integer = 24);
var
  i: integer;
  c: integer;
begin
  c := 0;
  for i := 0 to Rounds - 1 do begin
    KeccakRound(A, RoundConstants[c]);
    inc(c);
    if c = 255 then c := 0;
  end;
end;

procedure KeccakInitExState(out State: TKeccakExState; r: integer);
begin
  KeccakInitState(State.A);
  State.ip := 0;
  State.op := r;
  State.r := r;
end;

procedure KeccakAbsorb(var State: TKeccakExState; const Data; Size: integer);
// this routine uses busybody technique. as soon as the block is full,
// we do a keccak-f, thus we are prepared for further absorbing or squeezing
var
  i, ip, op: integer;
  P: PByte;
begin
  ip := State.ip;
  op := State.op;
  for i := 0 to Size - 1 do begin
    P := PByte(integer(@State.A)+ip);
    P^ := P^ xor PByte(integer(@Data)+i)^;
    ip := ip + 1;
    if ip >= State.r then begin
      KeccakF(State.A);
      op := 0;
      ip := 0;
    end;
  end;
  State.ip := ip;
  if (ip > 0) or (op > 0)
    then State.op := State.r
    else State.op := op;
end;

procedure KeccakSqueeze(var State: TKeccakExState; out Data; Size: integer);
// if there is unmixed data on the state, op = r
// in this case, we start with keccak-f
var
  P: PByte;
  op, r: integer;
begin
  P := @Data;
  op := State.op;
  r := State.r;
  repeat
    if op + Size <= r then begin
      Move(pointer( integer(@State.A) + op )^, P^, Size);
      State.op := op + Size;
      exit;
    end;
    Move(pointer( integer(@State.A) + op )^, P^, r - op);
    Size := Size - r + op;
    P := PByte(integer(P) + r - op);
    op := 0;
    KeccakF(State.A);
  until false;
end;

end.
