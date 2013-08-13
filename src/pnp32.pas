program pnp_stuffdir;

{&Use32+}
{$IfNDef VirtualPascal}
{$m 32768,0,655350}
{$EndIf}

{$g+}
{$s-}
{$d+}
{$R+}
{$I+}



{

A diagnostic PnP resource lister for PnP Equipped PC's.

This is freeware - do anything you like with it!


Note:

The unit newdelay may be omitted; it fixes the bug in TP that causes runtime
error 200 at startup on PentiumII-266 and faster CPU's, but does not otherwise
impact the program in any way.


Please visit http://members.hyperlink.net.au/~chart to contact the author,
obtain the latest version, or see what other hardware diagnostic tools I make.


}




uses
  {newdelay,}
  {$IfDef DPMI32}{$IfDef DEBUG}
  Deb_Link,
  {$EndIf}{$EndIf}
  {$IfDef AUFRUFST}
  Aufrufst,
  {HeapChk,MemLeaks,}
  {$EndIf AUFRUFST}
  {$IfDef SysUtils}
  SysUtils,
  {$EndIf}
  {$IfDef VirtualPascal}
  PnP_Prot,
  {$Else}
  PnP_Real,
  {$EndIf}

  PnPError,
  Objects,
  PnPId,
  RedirCon,
  Crt;

type
  smallword_ptr =^smallword;

  pnpisatype = record
    rev         : byte;
    CSNs        : byte;
    isaport     : smallword;
    reserved    : smallword;
  end;



const
  version       : string[5+2] = '0.14ávk';
  date                        = '2002.01.25';

var
  pnpisa        : pnpisatype;

  crd,
  bootype,
  retncode,
  i,
  j,
  e,
  f,
  g,
  h,
  k,
  x,
  wh,
  bl,
  flen,
  crn,
  where,
  vv,
  xx,
  pt,
  gh,
  minescdsize,
  escdsize,
  ld,
  numnodes,
  logicaldevs   : word;

  nvstoragebase : longint;

  exit_,
  pnp           : boolean;

  static,
  entrypoint    : pointer;

  tempnode,
  currentnode,
  a,b,c,d,
  slot,
  escdslots     : byte;

  try_string    : string[7];
  inp           : string[80];


  nodes         : array[0..50] of pByteArray;   { biggest it can be }
  escdbuff      : array[0..32767] of byte;      { biggest it can be }
  pnpres        : array[0..16383] of byte;
  csni          : array[$40..$ff] of byte;

  nodesize      :longint;
  resize_buffer :pByteArray;

function wrnib(byt:byte) : char;
  begin
    if byt<10 then wrnib:=Chr(Ord('0')+byt)
    else wrnib:=Chr(Ord('A')+byt-10);
  end;

function wrhex(byt:byte) : string;
  begin
    wrhex:=wrnib(byt shr 4)
          +wrnib(byt and $f);
  end;

function wrhexw(wor:smallword): string;
  begin
    wrhexw:=wrhex(Hi(wor))
           +wrhex(Lo(wor));
  end;

function wrhexl(l:longint): string;
  begin
    wrhexl:=wrhexw(l shr 16)
           +wrhexw(l and $ffff);
  end;


procedure displayEISAid(a,b,c,d:byte);
  begin
    Write(chr(a shr 2 + $40));
    Write(chr(((a and $3) shl 3) + (b shr 5) + $40));
    Write(chr((b and $1f) + $40));
    Write(wrhex(c));
    Write(wrhex(d));
    Write(' - ');

    try_string:=chr(a shr 2 + $40)
               +chr(((a and $3) shl 3) + (b shr 5) + $40)
               +chr((b and $1f) + $40)
               +wrhex(c)+wrhex(d);

    WriteLn(search_pnpid(try_string));
  end;


function Mem_where(const o:word):byte;{$IfDef VirtualPascal}inline;{$EndIf}
  begin
    Mem_where:=nodes[i]^[where+o];
  end;

function MemW_where(const o:word):word;{$IfDef VirtualPascal}inline;{$EndIf}
  begin
    MemW_where:=MemW[{$IFNDEF VirtualPascal}Seg(nodes[i]^):{$ENDIF}Ofs(nodes[i]^)+where+o];
  end;

function MemL_where(const o:word):longint;{$IfDef VirtualPascal}inline;{$EndIf}
  begin
    MemL_where:=MemL[{$IFNDEF VirtualPascal}Seg(nodes[i]^):{$ENDIF}Ofs(nodes[i]^)+where+o];
  end;


procedure ansistr;
  var
    stlen,ii : word;

  begin
    stlen:=MemW_where(1);
    Write('ID String       : ');

    for ii:=0 to stlen-1 do
      Write(Chr(Mem_where(3+ii)));

    Inc(where,stlen+3);
    WriteLn;
  end;


procedure pnpver;
  begin
    b:=nodes[i]^[where+1];
    Inc(where,3);
    WriteLn('Version         : ',wrhex(b shr 4),'h; Revision : ',wrhex(b and $0f),'h');
  end;

procedure logicaldevid;
  begin
    Write('LogicalDevID    : ');
    a:=nodes[i]^[where+1];
    b:=nodes[i]^[where+2];
    c:=nodes[i]^[where+3];
    d:=nodes[i]^[where+4];
    displayEISAid(a,b,c,d);
    Inc(where,(nodes[i]^[where] and 7)+1);
  end;

procedure mem16bit;
  begin
    Write('ISA Memory range: ');
    a:=nodes[i]^[where+3];
    e:=MemW_where(4);
    f:=MemW_where(6);
    g:=MemW_where(8);
    h:=MemW_where($a);
    Inc(where,MemW_where(1)+3);
    WriteLn('min ',wrhexw(e),'00h max ',wrhexw(f),'00h step ',wrhexw(g),'h length ',wrhexw(h*256),'h');

    Write('ISA Memory flags: ');
    if a and $40=$40 then Write('ExpROM, ');
    if a and $20=$20 then Write('ShadowOK, ');
    case a and $18 of
      $00 : Write('8-bit, ');
      $08 : Write('16-bit, ');
      $10 : Write('8 or 16-bit, ');
    end;
    if a and 4=4 then Write('DecodeHigh, ') else Write('DecodeLength, ');
    if a and 2=2 then Write('WriteThru Cached, ');
    if a and 1=1 then Write('Writeable') else Write('Write Protected');
    WriteLn;
  end;

procedure compatabledevid;
  begin
    Write('CompatableDevID : ');
    a:=nodes[i]^[where+1];
    b:=nodes[i]^[where+2];
    c:=nodes[i]^[where+3];
    d:=nodes[i]^[where+4];
    displayeisaid(a,b,c,d);
    Inc(where,5);
  end;

procedure fixedio;
  begin
    e:=MemW_where(1);
    b:=Mem_where(3)-1;
    Inc(where,4);
    WriteLn('Fixed I/O Range : ',wrhexw(e),'h to ',wrhexw(e+b),'h');
  end;

procedure irqresource;
  var
    n : byte;
    k : word;
  begin
    e:=MemW_where(1);
    b:=Mem_where(3)-1;
    Inc(where,(a and 3)+1);

    Write('IRQ(s)          : ');
    k:=1;
    for n:=0 to 15 do
      begin
        if e and k=k then Write(n,' ');
        k:=k shl 1;
      end;
    if a and 3=3 then
      begin
        if b=1 then WriteLn(' Edge, High' ) else
        if b=2 then WriteLn(' Edge, low'  ) else
        if b=4 then WriteLn(' Level, High') else
        if b=8 then WriteLn(' Level, low' ) else
      end;
    WriteLn;
  end;

procedure dmaresource;
  var
    n : byte;
    k : word;
  begin
    b:=nodes[i]^[where+1];
    c:=nodes[i]^[where+2];
    Inc(where,3);
    Write('DMA(s)          : ');
    k:=1;
    for n:=0 to 7 do
      begin
        if b and k=k then Write(n,' ');
        k:=k shl 1;
      end;
    case c and $60 of
      $60 : Write('- DMA Type F');
      $40 : Write('- DMA Type B');
      $20 : Write('- DMA Type A');
      $00 : Write('- DMA Type 8237');
    end;
    case c and $18 of
      $18 : Write(' Word or Byte count');
      $10 : Write(' Word Count');
      $08 : Write(' Byte Count');
      $00 : Write(' Reserved');
    end;
    if c and 4=4 then Write(' Bus Master');
    case c and 3 of
      3 : Write(' Reserved');
      2 : Write(' 16 Bit Transfers');
      1 : Write(' 8 or 16 bit Transfers');
      0 : Write(' 8 bit transfers');
    end;
    WriteLn;
  end;

procedure startdep;
  begin
    b:=nodes[i]^[where+1];
    if a and 3=0 then Inc(where,1) else Inc(where,2);
    Write('Alternate config start');
    if a and 3=1 then
      begin
        if b=0 then Write(' (Perferred Config)');
        if b=1 then Write(' (Other Config)');
        if b=2 then Write(' (Sub-Optimal Config)');
      end;
    WriteLn;
  end;

procedure enddep;
  begin
    Inc(where,1);
    WriteLn('Alternate config end');
  end;

procedure iorange;
  begin
    d:=Mem_where(1); { size }
    b:=Mem_where(6); { align }
    c:=Mem_where(7); { length }
    e:=MemW_where(2); { minbase }
    f:=MemW_where(4); { maxbase }
    Inc(where,8);

    if c=1 then
    begin
      Write('I/O Port        : ');
      WriteLn(wrhexw(e),'h');
    end else
    begin
      Write('I/O Range       : ');
      if e=f then WriteLn(wrhexw(e),'h to ',wrhexw(e+(c-1)),'h')
      else
      begin
        Write('Min ',wrhexw(e),'h max ');
        WriteLn(wrhexw(f),'h step ',wrhex(b),'h length ',wrhex(c),'h');
      end;
    end;
  end;

procedure vendor;
  begin
    Inc(where,(a and 7)+1);
    WriteLn('VendorSpecificData');
  end;

procedure mem32bit;
  begin
    e:=MemW_where(1);
    d:=nodes[i]^[where+3];
    Write('Memory          : Base ',
          wrhexl(MemL_where(4)),'h Length ',
          wrhexl(MemL_where(8)),'h');
    if d and $40=$40 then Write(' ExpROM');
    if d and $20=$20 then Write(' ShadowOK');
    case (d and $18) shr 3 of
      0 : Write(' 8 bit');
      1 : Write(' 16 bit');
      2 : Write(' 8+16 bit');
      3 : Write(' 32 bit');
    end;
    if d and $10=$10 then Write(' ExpROM');
    if d and $8=$8 then Write(' ExpROM');
    if d and $2=0 then Write(' Cacheable');
    if d and $1=0 then Write(' ROM');
    WriteLn;
    Inc(where,e+3);
  end;

{$I Classes.pas}

procedure versionstring;
  begin
    WriteLn('Plug and Play BIOS Data scanner, Version ',version,' By Craig Hart 1997,8');
    {$IfDef DPMI32}
    WriteLn('DPMI32 Port by Veit Kannegieser, ',date);
    {$EndIf}
    {$IfDef OS2}
    WriteLn('OS/2 Port by Veit Kannegieser, ',date);
    {$EndIf}
    WriteLn;
  end;

begin
  {$IfDef Aufrufst}
  install_exitproc;
  {$EndIf Aufrufst}

{ the following hack permits MS-DOS display output redirection to work }
  if ioredirected then
    begin
      versionstring;
      Assign(output,'');
      Rewrite(output);
    end
  else
    begin
      {TextMode(Co80+Font8x8);}
      ClrScr;
      install_pager;
    end;

  bootype:=1;

  if ParamCount>0 then
    begin
      inp:=ParamStr(1);
      if UpCase(inp[1])='N' then bootype:=2;
    end;

  versionstring;


  {$IfDef OS2}
  open_biospnp;
  {$EndIf OS2}

  Write('Plug ''n Play BIOS : ');
  vv:=0;
  pnp:=false;

  repeat (* '$PnP' *)
    if (MemW_F000(vv)=$5024) and (MemW_F000(vv+2)=$506e) then pnp:=true;
    Inc(vv,16);
  until (vv=$fff0) or pnp;

  if not pnp then
    begin
      WriteLn('no');
      Halt(1);
    end;

  Dec(vv,16);
  Write('Yes, v');
  WriteLn(chr(Mem_F000(vv+4) shr 4+ord('0')),'.',chr(Mem_F000(vv+4) and $f+ord('0')));

  {$IfDef VirtualPascal}
  entrypointp.ofs:=MemW_F000(vv+$11);
  entrypointp.physsegment:=MemL_F000(vv+$13);
  {$Else}
  entrypoint:=Ptr(MemW[$f000:vv+$0f],MemW[$f000:vv+$0d]);
  {$EndIf}


  {$IfDef VirtualPascal}
  setup_pnp_callcode(MemL_F000(vv+$13),MemW_F000(vv+$11),MemL_F000(vv+$1d));
  retncode:=Get_Number_of_System_Device_Nodes(numnodes,nodesize);
  {$Else}
  asm
    mov ax,0f000h                       { BiosSelector }
    push ax

    mov ax,seg nodesize                 { NodeSize }
    push ax
    mov ax,offset nodesize
    push ax

    mov ax,seg numnodes                 { NumNodes }
    push ax
    mov ax,offset numnodes
    push ax

    mov ax,0                            { Function 0 }
    push ax

    db $ff,$1e; dw entrypoint           { call far entrypoint }

    add sp,12
    mov retncode,ax

  end;
  {$EndIf}

  if retncode<>0 then
    WriteLn('Returned error code : ',wrhexw(retncode),'h',
      pnp_error_text(retncode));

  numnodes:=numnodes and $ff;

  WriteLn('Num System nodes  : ',numnodes);
  WriteLn('Largest node size : ',nodesize,' bytes');
  WriteLn('BIOS entry point  : ',
  {$IfDef VirtualPascal}
                                 wrhexl(entrypointp.physsegment),':',wrhexw(entrypointp.ofs),'h');
  {$Else}
                                 wrhexw(seg(entrypoint^)),':',wrhexw(ofs(entrypoint^)),'h');
  {$EndIf}

  Write('Report for        : ');
  if bootype=1 then WriteLn('Current Boot')
  else WriteLn('Next Boot');
  WriteLn;

  i:=0;
  tempnode:=i;

  repeat
    GetMem(nodes[i],nodesize);
    currentnode:=tempnode;
    {$IfDef VirtualPascal}
    retncode:=Get_System_Device_Node(tempnode,nodes[i]^,bootype);
    {$Else}
    asm
      mov ax,0f000h
      push ax
      mov ax,bootype                            { 1=now, 2=next boot }
      push ax
      mov ax,i
      mov bx,4
      mul bx
      mov si,ax
      mov ax,word ptr [nodes+si+2]
      push ax
      mov ax,word ptr [nodes+si]
      push ax
      mov ax,seg tempnode
      push ax
      mov ax,offset tempnode
      push ax
      mov ax,1
      push ax
      db $ff,$1e; dw entrypoint         { call far entrypoint }
      add sp,14
      mov retncode,ax
    end;
    {$EndIf}
    if retncode<>0 then
      begin
        WriteLn('Returned error code : ',wrhexw(retncode),'h Reading config!');
        WriteLn(pnp_error_text(retncode));
        Halt(1);
      end;

    if (smallword_ptr(@nodes[i]^[0])^>nodesize)
    or (nodes[i]^[2]<>currentnode) then
      begin
        WriteLn('Returned invalid values in buffer for handle ',currentnode,' !');
        FreeMem(nodes[i],nodesize);
        Continue;
      end;

    {$IfDef VirtualPascal}
    ReAllocMem(nodes[i],smallword_ptr(@nodes[i]^[0])^);
    {$Else}
    GetMem(resize_buffer,smallword_ptr(@nodes[i]^[0])^);
    Move(nodes[i]^,resize_buffer^,smallword_ptr(@nodes[i]^[0])^);
    FreeMem(nodes[i],nodesize);
    nodes[i]:=resize_buffer;
    {$EndIf}
    inc(i);
  until tempnode=$ff;

  numnodes:=i;

  load_pnpid_txt;


  for i:=0 to numnodes-1 do
    begin
      if terminate_request then Halt(1);
      WriteLn('------------------------------------------------------------------------------');
      Write('Device          : ',i,', size : ',smallword_ptr(@nodes[i]^[0])^);
      WriteLn(', Handle : ',nodes[i]^[2]);
      a:=nodes[i]^[3];
      b:=nodes[i]^[4];
      c:=nodes[i]^[5];
      d:=nodes[i]^[6];
      Write('PnP Device ID   : ');

      displayEISAid(a,b,c,d);

      a:=nodes[i]^[7];
      b:=nodes[i]^[8];
      c:=nodes[i]^[9];


      Write('BaseType        : ',a,' - ');
      if a in [Low(pci_class_names)..High(pci_class_names)] then
        Write(pci_class_names[a]);

      WriteLn;

      Write('SubType         : ',b,' - ');
      for j:=Low(pci_class_array) to High(pci_class_array) do
        with pci_class_array[j] do
          if (a=class_) and (b=subclass) and (0=progif) then
            begin
              Write(cname);
              Break;
            end;

      WriteLn;
      Write('InterfaceType   : ',c);
      if c<>0 then
        begin
          Write(' - ');

          for j:=Low(pci_class_array) to High(pci_class_array)+1 do
            if j=High(pci_class_array)+1 then
              Write('Unknown!')
            else
              with pci_class_array[j] do
                if (a=class_) and (b=subclass) and (c=progif) then
                  begin
                    Write(cname);
                    Break;
                  end;
        end;
      WriteLn;

      a:=nodes[i]^[10];
      b:=nodes[i]^[11];

      Write('DevAttribs      : ');

      j:=128;
      repeat
        if b and j=j then Write('1') else Write('0');
        j:=j shr 1;
      until j=0;

      Write(' ');

      j:=128;
      repeat
        if a and j=j then Write('1') else Write('0');
        j:=j shr 1;
      until j=0;

      WriteLn;



{ decode variable resource allocations }


      if smallword_ptr(@nodes[i]^[0])^>11 then
        begin
          where:=12;
          exit_:=false;


          repeat
            a:=nodes[i]^[where];

            if a and $80=$80 then
              begin
                case a and $7f of
                  1 : mem16bit;
                  2 : ansistr;
                  6 : mem32bit;
                else
                    WriteLn('Tripped out on big code ',wrhex(a and $7f));
                    inc(where);
                end;
              end
            else
              begin
                case a shr 3 of
                    1 : pnpver;
                    2 : logicaldevid;
                    3 : compatabledevid;
                    4 : irqresource;
                    5 : dmaresource;
                    6 : startdep;
                    7 : enddep;
                    8 : iorange;
                    9 : fixedio;
                   $e : vendor;
                   $f : begin
                          WriteLn('End tag');
                          where:=where+2;
                          if nodes[i]^[10] and $80<>$80 then exit_:=true;
                        end;

                else
                  begin
                    WriteLn('Tripped out on small code ',wrhex(a shr 3));
                    inc(where);
                  end;
                end;


              end;

            if where>=smallword_ptr(@nodes[i]^[0])^ then exit_:=true;
          until exit_;
        end;
    end; (* numnodes-1 *)


  WriteLn;
  WriteLn;
  WriteLn;
  WriteLn('Plug ''n Play ISA Configuration');
  WriteLn;

  FillChar(pnpisa,SizeOf(pnpisa),$00);
  {$IfDef VirtualPascal}
  retncode:=Get_Plug_and_Play_ISA_Configuration_Structure(pnpisa);
  {$Else}
  asm
    int 3
    mov ax,0f000h
    push ax

    mov ax,seg pnpisa
    push ax
    mov ax,offset pnpisa
    push ax

    mov ax,040h
    push ax
    db $ff,$1e; dw entrypoint         { call far entrypoint }
    add sp,8
    mov retncode,ax
  end;
  {$EndIf}
  if retncode<>0 then
    WriteLn('Returned error code : ',wrhexw(retncode),'h',
      pnp_error_text(retncode))
  else
    begin

      WriteLn('Revision        : ',pnpisa.rev);
      WriteLn('CSN''s (Cards)   : ',pnpisa.csns);
      Write('ISA read port   : ');
      if pnpisa.csns=0 then
        WriteLn('Not Valid')
      else
        begin
          WriteLn(wrhexw(pnpisa.isaport),'h');
          WriteLn;



{ return cards to wait-for-key, don't clear CSN's or reset cards }

          port[$279]:=2;
          port[$a79]:=2;


{ send key sequence }

          {$IfDef VirtualPascal}
          asm {&Alters EAX,EBX,ECX,EDX}
            mov dx,0279h
            mov al,0
            call _Out8
            call _Out8

            mov ecx,32
            mov al,06ah

        @next:
            mov bh,al
            mov bl,al
            shr bl,1
            and bl,1
            and bh,1
            xor bh,bl
            shl bh,7
            call _Out8
            shr al,1
            or al,bh
            loop @next
          end;
          {$Else}
          asm
            mov dx,0279h
            mov al,0
            out dx,al
            out dx,al

            mov cx,32
            mov al,06ah

          @next:
            mov bh,al
            mov bl,al
            shr bl,1
            and bl,1
            and bh,1
            xor bh,bl
            shl bh,7
            out dx,al
            shr al,1
            or al,bh
            loop @next
          end;
          {$EndIf}


          for crd:=1 to pnpisa.csns do
            begin
              if terminate_request then Halt(1);
              port[$279]:=3; { wake command reg }
              port[$a79]:=crd; {CSN #... }

              for i:=0 to 1023 do
                begin
                  port[$279]:=5;
                  repeat until port[pnpisa.isaport] and 1=1;
                  port[$279]:=4;
                  pnpres[i]:=port[pnpisa.isaport];
                end;

              x:=1024;
              GetMem(nodes[50],x);
              Move(pnpres,nodes[50]^,x);


              WriteLn('------------------------------------------------------------------------------');
              WriteLn('Possible configuration(s) for Card #',crd);
              WriteLn;
              Write('PnPISA Device ID: ');

              displayeisaid(pnpres[0],pnpres[1],pnpres[2],pnpres[3]);
              WriteLn('Serial#         : ',wrhex(pnpres[7]),wrhex(pnpres[6]),
                wrhex(pnpres[5]),wrhex(pnpres[4]),'h');



              logicaldevs:=$ffff;

              where:=9;
              exit_:=false;
              i:=50;
              repeat
                a:=nodes[i]^[where];
                if a and $80=$80 then
                  begin
                    case a and $7f of
                      1 : mem16bit;
                      2 : ansistr;
                      6 : mem32bit;
                    else
                        WriteLn('Tripped out on big code ',wrhex(a and $7f));
                        inc(where);
                    end;
                  end
                else
                  begin
                    case a shr 3 of
                      1 : pnpver;
                      2 : begin
                            logicaldevid;
                            inc(logicaldevs);
                          end;
                      3 : compatabledevid;
                      4 : irqresource;
                      5 : dmaresource;
                      6 : startdep;
                      7 : enddep;
                      8 : iorange;
                      9 : fixedio;
                     $e : vendor;
                     $f : begin
                            WriteLn('End tag');
                            where:=where+2;
                            exit_:=true;
                          end;
                    else
                      WriteLn('Tripped out on small code ',wrhex(a shr 3));
                      inc(where);
                    end;
                  end;

                if where>=x then exit_:=true;
              until exit_;

{ Safeguard! }
              if logicaldevs=$ffff then logicaldevs:=1;

              WriteLn;
              WriteLn('Logical devices : ',logicaldevs+1);




              WriteLn;
              WriteLn;
              WriteLn('Current configuration');
              WriteLn;


              for ld:=0 to logicaldevs do
                begin
                  WriteLn('--- Logical Device ',ld,' ---');



{ read enabled bit }
                  port[$279]:=7;
                  port[$a79]:=ld;
                  Write('Enabled : ');
                  port[$279]:=$30;
                  if port[pnpisa.isaport] and 1=1 then WriteLn('Yes')
                  else WriteLn('No');


{ read resources for this logical device & display }
                  for i:=$40 to $ff do
                    begin
                      port[$279]:=5;
                      repeat until port[pnpisa.isaport] and 1=1;
                      port[$279]:=i;
                      csni[i]:=port[pnpisa.isaport];
                    end;


{ IRQ }
                  if csni[$70]>0 then
                    begin
                      Write('IRQ #1  : ',csni[$70],', ');
                      case csni[$71] of
                        00 : WriteLn('Edge triggered, H->L');
                        01 : WriteLn('Active low level triggered');
                        02 : WriteLn('Edge triggered, L->H');
                        03 : WriteLn('Active high level triggered');
                      end;
                    end;

                  if csni[$72]>0 then
                    begin
                      Write('IRQ #2  : ',csni[$72],', ');
                      case csni[$73] of
                        00 : WriteLn('Edge triggered, H->L');
                        01 : WriteLn('Active low level triggered');
                        02 : WriteLn('Edge triggered, L->H');
                        03 : WriteLn('Active high level triggered');
                      end;
                    end;

{ DMA }
                  if csni[$74]<>4 then WriteLn('DMA #1  : ',csni[$74]);
                  if csni[$75]<>4 then WriteLn('DMA #2  : ',csni[$75]);
{ i/o }
                  for i:=0 to 7 do
                    if (csni[$60+(i shl 1)]<>0)
                    or (csni[$61+(i shl 1)]<>0) then
                      WriteLn('I/O #',i,'  : ',wrhex(csni[$60+(i shl 1)]),
                                               wrhex(csni[$61+(i shl 1)]),'h');

{ isa mem }
                  for i:=0 to 3 do
                    begin
                      if (csni[$40+(i*8)]<>00)
                      or (csni[$41+(i*8)]<>00)
                      or (csni[$42+(i*8)]<>00)
                      or (csni[$43+(i*8)]<>00)
                      or (csni[$44+(i*8)]<>00) then
                        begin

                          Write('MEM #',i,'  : ',wrhex(csni[$40+(i*8)]),wrhex(csni[$41+(i*8)]),'00h ');
                          if csni[$42+(i*8)] and 1=1 then
                            begin
                              Write('to ');
                              Write(wrhex(csni[$43+(i*8)]),wrhex(csni[$44+(i*8)]),'00h');
                            end
                          else
                            begin
                              Write('length ');
                              Write(wrhex(csni[$43+(i*8)]),wrhex(csni[$44+(i*8)]),'h');
                            end;

                          if csni[$42+(i*8)] and 2=2 then Write(' 16-bit')
                          else                            Write(' 8-bit');
                          WriteLn;
                        end;
                    end;

{ Need to implement EISA mem! }

                  WriteLn;

                end; (* ..logicaldevs *)

            end; (* crd:=1 to pnpisa.csns *)

        end; (* pnpisa.csns<>0 *)

    end; (* retncode=0 *)



  WriteLn;
  WriteLn;
  WriteLn;
  WriteLn('Static Resource Configuration');
  WriteLn;
  GetMem(static,8192);

  {$IfDef VirtualPascal}
  retncode:=Get_Statically_Allocated_Resource_Information(static^);
  {$Else}
  asm
    mov ax,0f000h
    push ax

    mov ax,word ptr static+2
    push ax
    mov ax,word ptr static
    push ax

    mov ax,0ah
    push ax
    db $ff,$1e; dw entrypoint         { call far entrypoint }
    add sp,8
    mov retncode,ax
  end;
  {$EndIf}
  if retncode<>0 then
    begin
      Write('Returned error code : ',wrhexw(retncode),'h');
      if retncode=$8d then WriteLn(' - Refer to ESCD information instead!')
      else WriteLn(pnp_error_text(retncode));
    end;

{ sorry, no further work on Static Resources yet..! ..never met a pc that uses it!!}


  WriteLn;
  WriteLn;
  WriteLn;
  WriteLn('ESCD Information');
  WriteLn;

  {$IfDef VirtualPascal}
  retncode:=Get_Extended_System_Configuration_Data_Info(minescdsize,escdsize,nvstoragebase);
  {$Else}
  asm
    mov ax,0f000h
    push ax

    mov ax,seg nvstoragebase
    push ax
    mov ax,offset nvstoragebase
    push ax

    mov ax,seg escdsize
    push ax
    mov ax,offset escdsize
    push ax

    mov ax,seg minescdsize
    push ax
    mov ax,offset minescdsize
    push ax

    mov ax,041h
    push ax
    db $ff,$1e; dw entrypoint         { call far entrypoint }
    add sp,14
    mov retncode,ax
  end;
  {$EndIf}
  if retncode<>0 then
    WriteLn('Returned error code : ',wrhexw(retncode),'h',
      pnp_error_text(retncode));


  WriteLn('ESCD Size      : ',escdsize);
  WriteLn('Min ESCD Size  : ',minescdsize);
  Write('NVStorBase     : ',wrhex(nvstoragebase shr 24));
  Write(wrhex((nvstoragebase shr 16) and $ff));
  Write(wrhex((nvstoragebase shr 8) and $ff));
  WriteLn(wrhex(nvstoragebase and $ff),'h');

  WriteLn;

  if (escdsize>0) and (escdsize<32769) then
    begin

      {$IfDef VirtualPascal}
      retncode:=Read_Extended_System_Configuration_Data(escdbuff,nvstoragebase,escdsize);
      {$Else}
      asm
        mov ax,0f000h
        push ax

        mov bx,word ptr nvstoragebase+2
        mov ax,word ptr nvstoragebase

        shr ax,4
        shl bx,12
        add ax,bx
        push ax


        mov ax,seg escdbuff
        push ax
        mov ax,offset escdbuff
        push ax

        mov ax,042h
        push ax
        db $ff,$1e; dw entrypoint               { call far entrypoint }
        add sp,10
        mov retncode,ax
      end;
      {$EndIf}
      if retncode<>0 then
        WriteLn('Returned error code : ',wrhexw(retncode),'h',
          pnp_error_text(retncode));


      WriteLn('Signature      : ',chr(escdbuff[2]),chr(escdbuff[3]),chr(escdbuff[4]),chr(escdbuff[5]));



      WriteLn('Version        : ',wrhex(escdbuff[7]),'.',wrhex(escdbuff[6]));
      WriteLn('Board Count    : ',escdbuff[8]);
      WriteLn('Size           : ',wrhex(escdbuff[1]),wrhex(escdbuff[0]),'h');
      WriteLn;


{ try to decode ESCD }
      escdslots:=0;

      where:=12;
      repeat
        if terminate_request then Halt(1);
        slot:=escdbuff[where+2];

        inc(escdslots);
        if slot<>255 then
          begin
            WriteLn('------------------------------------------------------------------------------');
            Write('Slot #',wrhex(slot),'h');

            case slot of
              0 :      Write(' System Board Resources');
              1..15 :  Write(' EISA, PnPISA or ISA Adapter');
              16..64 : Write(' Virtual Adapter');
            end;


            e:=smallword_ptr(@escdbuff[where])^;
            WriteLn(' Size : ',wrhexw(e),'h');



            WriteLn;
            WriteLn('(Hex-dump of ESCD data for this device follows)');
            crn:=24;
            for wh:=where to (where+e)-1 do
              begin
                Write(wrhex(escdbuff[wh]),' ');
                inc(crn);
                if ((crn+1) mod 25)=0 then WriteLn;
              end;
            WriteLn;
            WriteLn;


  { decode basic device info }

            Write('EISA ID   : ');

            if  (escdbuff[where+4]=0)
            and (escdbuff[where+5]=0)
            and (escdbuff[where+6]=0)
            and (escdbuff[where+7]=0) then
              WriteLn('Not Defined')
            else
              displayeisaid(escdbuff[where+4],
                            escdbuff[where+5],
                            escdbuff[where+6],
                            escdbuff[where+7]);

            WriteLn('Slot Info : ',wrhex(escdbuff[where+8]),'h, ',wrhex(escdbuff[where+9]),'h');
            WriteLn('CFG Revn  : ',escdbuff[where+10],'.',escdbuff[where+11]);
            WriteLn;

            bl:=0;
            xx:=where+$0c;

            repeat
              flen:=escdbuff[xx+1] shl 8 + escdbuff[xx];

              if flen>0 then
                begin
                  WriteLn;
                  WriteLn('-- Function ',bl,' -----------------------');
                  WriteLn;


    { Only needed for debugging ...}
                   WriteLn('Length  : ',wrhexw(flen),'h');
                   WriteLn('Fn info : ',wrhex(escdbuff[xx+4]),'h');



    { Decode functions }

                  pt:=xx+5;

                  if escdbuff[xx+4] and $80=$80 then
                    begin
                      { disabled record }
                      WriteLn('(This entry is disabled)');
                    end;
                  if escdbuff[xx+4] and $40=$40 then
                    begin
                      { freeform record }
                      WriteLn('(This entry is really freeform data)');
                    end;

                  if escdbuff[xx+4] and $1=$1 then
                    begin
                      { ?? record }
                      WriteLn('(Type 01h - Not implemented)');
                      inc(pt,80);
                    end;

                  if escdbuff[xx+4] and $20=$20 then
                    begin
                      { ?? record }
                      WriteLn('(Type 20h - Not implemented)');
                      inc(pt,3);
                    end;

                  if escdbuff[xx+4] and 2=2 then
                    begin
                      { Memory record }
                      repeat
                        gh:=escdbuff[pt+6] shl 8 + escdbuff[pt+5];
                        Write('MEM     : ',wrhex(escdbuff[pt+4]),wrhex(escdbuff[pt+3]),wrhex(escdbuff[pt+2]),'0h');
                        Write(' Length ',gh,'kb, ');

                        if escdbuff[pt] and 1=1 then Write('RAM, ') else Write('ROM, ');
                        if escdbuff[pt] and 2=2 then Write('Cached, ') else Write('Not Cached, ');
                        if escdbuff[pt] and $20=$20 then Write('Shared, ') else Write('Not Shared, ');

      {                  case escdbuff[pt] and $18 of
                          $00 : Write('System ');
                          $08 : Write('Expanded ');
                          $10 : Write('Virtual ');
                          $18 : Write('Other ');
                        end;
                        Write('Memory, ');
      }

                        case escdbuff[pt+1] and 3 of
                          00 : Write('8-bit');
                          01 : Write('16-bit');
                          02 : Write('32-bit');
                          03 : Write('??-bit');
                        end;

                        WriteLn;



                        inc(pt,7);
                      until escdbuff[pt-7] and $80=$0;
                    end;

                  if escdbuff[xx+4] and 4=4 then
                    begin
                      { IRQ record }
                      repeat
                        Write('IRQ     : ',(escdbuff[pt] and $f),', ');

                        if escdbuff[pt] and $20=$20 then Write('Level ') else Write('Edge ');
                        Write('Triggered, ');

                        if escdbuff[pt] and $40=0 then Write('Not ');
                        WriteLn('Shared');

                        inc(pt,2);
                      until escdbuff[pt-2] and $80=$0;
                    end;

                  if escdbuff[xx+4] and 8=8 then
                    begin
                      { DMA record }
                      repeat
                        Write('DMA     : ',(escdbuff[pt] and $f),', ');

                        if escdbuff[pt] and $40=0 then Write('Not ');
                        Write('Shared, ');

                        case escdbuff[pt+1] and $30 of
                          $00 : Write('ISA');
                          $10 : Write('Type A');
                          $20 : Write('Type B');
                          $30 : Write('Burst');
                        end;
                        Write(' Timing, ');

                        case escdbuff[pt+1] and $c0 of
                          $00 : WriteLn('8-bit');
                          $40 : WriteLn('16-bit');
                          $80 : WriteLn('32-bit');
                          $c0 : WriteLn('Reserved');
                        end;

                        inc(pt,2);
                      until escdbuff[pt-2] and $80=$0;
                    end;

                  if escdbuff[xx+4] and $10=$10 then
                    begin
                      { I/O record }
                      repeat
                        gh:=escdbuff[pt+2] shl 8 + escdbuff[pt+1];
                        Write('I/O     : ',wrhexw(gh),'h to ',wrhexw(gh+(escdbuff[pt] and $7f)),'h, ');

                        if escdbuff[pt] and $40=0 then Write('Not ');
                        WriteLn('Shared');


                        inc(pt,3);
                      until escdbuff[pt-3] and $80=$0;
                    end;


                end (* flen>0 *)
              else
                begin
                  WriteLn;
                  WriteLn('-- Last Function -- Checksum ',wrhex(escdbuff[xx+flen+2]),wrhex(escdbuff[xx+flen+3]),'h --');
                  WriteLn;
                end;

              inc(bl);
              xx:=xx+flen+2;
            until flen=0;


      { Scan for any (optional) ESCD extras }

            for xx:=where to where+e do

              if (escdbuff[xx  ]=ord('A')) and
                 (escdbuff[xx+1]=ord('C')) and
                 (escdbuff[xx+2]=ord('F')) and
                 (escdbuff[xx+3]=ord('G')) then
                begin

                  WriteLn;
                  WriteLn('-- Freeform board header found for this device --');
                  WriteLn;
                  Write('    Signature  : ');
                  WriteLn(chr(escdbuff[xx]),chr(escdbuff[xx+1]),chr(escdbuff[xx+2]),chr(escdbuff[xx+3]));
                  WriteLn('    Version    : ',escdbuff[xx+5],'.',escdbuff[xx+4]);
                  Write('    DeviceType : ');


                  case escdbuff[xx+6] of
                    $01 : WriteLn('Non-PnP ISA');
                    $02 : WriteLn('EISA');
                    $04 : begin
                            WriteLn('PCI');
                            WriteLn('    PCI BUS#   : ',wrhex(escdbuff[xx+$10]),'h');
                            WriteLn('    PCI Func#  : ',wrhex(escdbuff[xx+$10+1]),'h');
                            WriteLn('    PCI Vendor : ',wrhex(escdbuff[xx+$10+5]),wrhex(escdbuff[xx+$10+4]),'h');
                            WriteLn('    PCI Device : ',wrhex(escdbuff[xx+$10+3]),wrhex(escdbuff[xx+$10+2]),'h');
                          end;
                    $08 : WriteLn('PCMCIA');
                    $10 : begin
                            WriteLn('PnPISA');
                            Write('    DeviceID   : ');
                            displayeisaid(escdbuff[xx+$10],escdbuff[xx+$11],escdbuff[xx+$12],escdbuff[xx+$13]);
                            WriteLn('    Serial#    : ',wrhex(escdbuff[xx+$17]),wrhex(escdbuff[xx+$16]),
                              wrhex(escdbuff[xx+$15]),wrhex(escdbuff[xx+$14]),'h');
                          end;
                    $20 : WriteLn('MCA');
                    $40 : begin
                            WriteLn('PCI Bridge');
                            WriteLn('    PCI BUS#   : ',wrhex(escdbuff[xx+$10]),'h');
                            WriteLn('    PCI Func#  : ',wrhex(escdbuff[xx+$10+1]),'h');
                            WriteLn('    PCI Vendor : ',wrhex(escdbuff[xx+$10+5]),wrhex(escdbuff[xx+$10+4]),'h');
                            WriteLn('    PCI Device : ',wrhex(escdbuff[xx+$10+3]),wrhex(escdbuff[xx+$10+2]),'h');
                          end;
                  else
                         WriteLn('Unknown (',wrhex(escdbuff[xx+6]),'h)');
                  end;
                  WriteLn;
                  WriteLn('-- Freeform board header ends -------------------');
                  WriteLn;
                end;

            where:=where+e;
            WriteLn('------------------------------------------------------------------------------');
            WriteLn;
            WriteLn;
          end; (* slot<>255 *)
      until (where>=escdsize) or (slot=255) or (escdslots=escdbuff[8]);

    end (* valid escdsize *)
  else
    begin
      if escdsize=0 then WriteLn('ESCD size 0 bytes !?!?!')
      else WriteLn('ESCD size >32k, cannot read!!!');
    end;

  freemem(static,8192);
  for i:=0 to numnodes-1 do
    freemem(nodes[i],nodesize);

  {$IfDef VirtualPascal}
  release_pnp_code;
  {$EndIf VirtualPascal}
  free_pnpid_txt;

end.

