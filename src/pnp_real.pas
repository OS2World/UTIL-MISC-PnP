unit pnp_real;

interface

type
  smallword             =word;

function Mem_F000(const i:word):smallword;
function MemW_F000(const i:word):smallword;

implementation

function Mem_F000(const i:word):smallword;
  begin
    Mem_F000:=Mem[$f000:i];
  end;

function MemW_F000(const i:word):smallword;
  begin
    MemW_F000:=MemW[$f000:i];
  end;

end.