(* paging functions *)

{&Use32+}
{$G+}
{$R+}
{$S-}
{$I+}
{$N-}

unit RedirCon;

interface

const
  terminate_request:boolean=false;

procedure install_pager;
function  ioredirected:boolean;
{$IfNDef VirtualPascal}
procedure SetLength(var s:string;const l:word);
{$EndIf}

implementation

uses
  {$IfDef VirtualPascal}
  VpSysLow,
  VpUtils,
  {$EndIf}
  Crt,
  Dos;

var
  linecounter   : word;
  org_output    : pointer;

{$IfDef VirtualPascal}
procedure pagefilter1(var t:text);{&Saves All}
  var
     z:word;
  begin
    with TextRec(t) do
      for z:=1 to BufPos do
        if BufPtr^[z]=#10 then
          Inc(linecounter);
  end;


procedure pagefilter2;{&Saves All}
  begin
    if (linecounter>=Hi(WindMax)) and (WhereX=1) then
      begin
        {$IfNDef Debug}
        case SysReadKey of
          #$00,#$e0:
            case SysReadKey of
              #$2d: (* Alt+X *)
                terminate_request:=true;
            end;
          #27: (* Esc *)
             terminate_request:=true;
          'Q','q':
             terminate_request:=true;
        end;
        {$EndIf}
        linecounter:=0;
      end;
  end;

procedure page_output_FlushFunc;assembler;{&Uses None}{$Frame-}
  asm
    push ebx
    call pagefilter1
    push ebx
    call [org_output]
    call pagefilter2
    ret 4
  end;

{$Else} (* BP *)

procedure pagefilter1(var t:text);assembler;
asm
  push ax
  push di
  push es
  push cx

  les di,[t]
  mov cx,es:[di+TextRec.BufPos]
  les di,es:[di+TextRec.BufPtr]
  cld
  mov al,10

@sl:
  jcxz @ret
  dec cx
  scasb
  jne @sl
  inc linecounter
  jmp @sl

@ret:
  pop cx
  pop es
  pop di
  pop ax
end;

procedure pagefilter2;assembler;
asm
  push ax
  mov ax,WindMax
  shr ax,8
  cmp linecounter,ax
  jb @ret

  sub ax,ax
  int $16
  cmp al,'q'
  je @terminate_req
  cmp al,'Q'
  je @terminate_req
  cmp al,27
  je @terminate_req
  cmp ax,$2d00
  jne @no_terminate_req
@terminate_req:
  mov terminate_request,true
@no_terminate_req:
  mov linecounter,0

@ret:
  pop ax
end;

procedure page_output_FlushFunc;assembler;
asm
  push es
  push bx
  call pagefilter1
  push es
  push bx
  call [org_output]
  call pagefilter2
  retf 4
end;
{$EndIf} (* BP *)

procedure install_pager;
  begin
    linecounter:=0;
    with TextRec(Output) do
      begin
        org_output:=FlushFunc;
        FlushFunc:=@page_output_FlushFunc;
      end;
  end;

{$IfDef VirtualPascal}
function IORedirected : boolean ;
  begin
    IORedirected:=not VPUtils.IsFileHandleConsole(SysFileStdOut);
  end;
{$Else}
function IORedirected : boolean ; Assembler;
asm
  push ds
  mov ax,prefixseg
  mov ds,ax
  xor bx,bx
  les bx,[bx + $34]
  mov al,es:[bx]
  mov ah,es:[bx +1]
  pop ds
  cmp al,ah
  mov al,true
  jne @exit

  mov al,false

 @exit:
end;
{$EndIf}


{$IfNDef VirtualPascal}
procedure SetLength(var s:string;const l:word);
  begin
    s[0]:=Chr(l);
  end;
{$EndIf}


end.

