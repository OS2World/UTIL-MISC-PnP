{&Use32+}
unit pnp_prot;

interface

{$IfDef OS2}

const
  bios_pnp_kategorie    =$80;

  funktion_PhysToUVirt  =$00;

type
  prot_mode_ptr_typ     =
    packed record
      ofs               :word;
      sel               :smallword;
    end;

var
  bios_pnp              :word=0;
  memf0000              :array[0..$ffff] of byte;
{$EndIf OS2}

{$IfDef DPMI32}
uses
  Dpmi32,
  Dpmi32df;

const
  SegF000               =$f0000;
{$EndIf DPMI32}


var
  entrypointp           :
    record
      ofs               : smallword;
      physsegment       : word;
    end;

  pnp_linear            :longint;

  entrypoint            :prot_mode_ptr_typ=(ofs:0;sel:0);

  {$IfDef DPMI32}
  stack16prot           :prot_mode_ptr_typ;
  stack_pascal          :prot_mode_ptr_typ;
  {$EndIf DPMI32}

  bios_sel              :prot_mode_ptr_typ;

  {$IfDef DPMI32}
  code16prot            :prot_mode_ptr_typ;
  code16pos             :word;
  code16feld            :array[0..$3f] of byte;
  {$EndIf DPMI32}

  {$IfDef OS2}
  stack_array           :array[1..20] of smallword;
  {$EndIf OS2}

  para_stack_used       :word;

{$IfDef OS2}
procedure open_biospnp;
{$EndIf OS2}
procedure setup_pnp_callcode(const cs,eip,phys_bios:longint);
procedure setup_escd_selector(const physaddr:longint);
procedure release_pnp_code;

function mem_f000(const o:word):byte;
function memw_f000(const o:word):smallword;
function meml_f000(const o:word):longint;


// $00
function Get_Number_of_System_Device_Nodes(var number_of_device_nodes:word;var size_of_largest_device_node:longint):word;
// $01
function Get_System_Device_Node(var node_number_or_handle:byte;var buffer;const control_flag:smallword):word;
// $0a
function Get_Statically_Allocated_Resource_Information(var buffer):word;
// $40
function Get_Plug_and_Play_ISA_Configuration_Structure(var buffer):word;
// $41
function Get_Extended_System_Configuration_Data_Info(var nonvolatile_storage:word;var ESCD_allocated:word;var base_address_of_NV_storage:longint):word;
// $42
function Read_Extended_System_Configuration_Data(var buffer;const addr_ESCD,size_ESCD:longint):word;

implementation

uses
  {$IfDef OS2}
  Os2Def,
  Os2Base,
  {$EndIf OS2}
  VpUtils;

type
  smallword_ptr         =^smallword;
  longint_ptr           =^longint;

const
  stacksize             =8*1024;
  buffersize            :longint=0;
  ecsdsize              =32768;

var
  pnp_stack             :array[0..stacksize-1] of byte;

  data_buffer           :array[0..$ffff] of byte;
  {$IfDef OS2}
  data_buffer_used      :word;
  {$EndIf}

  data_longint_1        :longint_ptr=@data_buffer[$0];
  data_longint_2        :longint_ptr=@data_buffer[$4];
  data_longint_3        :longint_ptr=@data_buffer[$8];
  data_buffer32         :pointer    =@data_buffer[$c];
  data_longint_1_1616   :longint_ptr=@data_buffer[$0];
  data_longint_2_1616   :longint_ptr=@data_buffer[$4];
  data_longint_3_1616   :longint_ptr=@data_buffer[$8];
  data_buffer1616       :pointer    =@data_buffer[$c];

  data_sel              :prot_mode_ptr_typ;
  escd_sel              :prot_mode_ptr_typ;


function mem_f000(const o:word):byte;
  begin
    {$IfDef OS2}
    mem_f000:=memf0000[o];
    {$EndIf OS2}
    {$IfDef DPMI32}
    mem_f000:=Mem[SegF000+o];
    {$EndIf}
  end;

function memw_f000(const o:word):smallword;
  begin
    {$IfDef OS2}
    memw_f000:=smallword_ptr(@memf0000[o])^;
    {$EndIf OS2}
    {$IfDef DPMI32}
    memw_f000:=MemW[SegF000+o];
    {$EndIf}
  end;

function meml_f000(const o:word):longint;
  begin
    {$IfDef OS2}
    meml_f000:=longint_ptr(@memf0000[o])^;
    {$EndIf OS2}
    {$IfDef DPMI32}
    meml_f000:=MemL[SegF000+o];
    {$EndIf}
  end;


// DPMI32
const
  descriptor_granularity_byte                   =0 shl 15;
  descriptor_granularity_page                   =1 shl 15;
  descriptor_granularity                        =1 shl 15;
  descriptor_default_operation_size_16          =0 shl 14;
  descriptor_default_operation_size_32          =1 shl 14;
  descriptor_default_operation_size             =1 shl 14;
  // 13:0
  // 12:available
  // 11..8:part of segemnt limit
  descriptor_segement_present                   =1 shl  7;
  // 6/5: descriptor privilege level
  // 4: 0=system segment 1=code/data segment
  // 3: system segment: TSS/GATE/..; code/data:
  descriptor_access_data_readonly               =0 shl 1;
  descriptor_access_data_readwrite              =1 shl 1;
  descriptor_access_data_readonly_expanddown    =2 shl 1;
  descriptor_access_data_readwrite_expanddown   =3 shl 1;
  descriptor_access_execute_only                =4 shl 1;
  descriptor_access_execute_read                =5 shl 1;
  descriptor_access_execute_only_conforming     =6 shl 1;
  descriptor_access_execute_read_conforming     =7 shl 1;
  descriptor_access                             =7 shl 1;
  // 0: accessed

// OS/2
const
  OS2_SELTYPE_R3CODE    =0;     // get virtual address, make segment readable/executable
                                // with application program privilege.
  OS2_SELTYPE_R3DATA    =1;     // get virtual address, make segment readable writable
                                // with application program privilege.
  OS2_SELTYPE_FREE      =2;     // free virtual address (OS/2 mode only)

  OS2_SELTYPE_R2CODE    =3;     // get virtual address, make segment readable/executable
                                // with I/O privilege.
  OS2_SELTYPE_R2DATA    =4;     // get virtual address, make segment readable/writable
                                // with I/O privilege.
  OS2_SELTYPE_R3VIDEO   =5;     // get virtual address, make segment readable/writable
                                // with Application Program Privilege and assign it with a tag.

{$IfDef OS2}
function allocate_selector(var sel:smallword):longint;
  begin
    sel:=0;
    allocate_selector:=0;
  end;


procedure PhysToUVirt(const ax_,bx_,cx_:smallword;const dh_:byte;var sel_,ofs_:smallword);
  var
    para                :
      packed record
        _ax,
        _bx,
        _cx             :smallword;
        _dh             :byte;
        _sel,
        _ofs            :smallword;
      end;
    para_len            :word;
    rc                  :ApiRet;
  begin
    para_len:=SizeOf(para);
    with para do
      begin
        _ax:=ax_;
        _bx:=bx_;
        _cx:=cx_;
        _dh:=dh_;
        _sel:=sel_;
        _ofs:=ofs_;
      end;

    rc:=DosDevIOCtl(bios_pnp,bios_pnp_kategorie,funktion_PhysToUVirt,
          @para,para_len,@para_len,
          nil  ,0    ,nil         );

    if rc<>0 then
      begin
        WriteLn('PhysToUVirt Error.');
        Halt(255);
      end;

    sel_:=para._sel;
    ofs_:=para._ofs;

  end;

function set_selector(var sel:smallword;const base,length,seltype_not,seltype_or:longint;const os2_sel_typ:byte):longint;
  var
    ofs_:smallword;
  begin
    if sel<>0 then RunError(87);

    PhysToUVirt(base shr 16,base and $ffff,length and $ffff,os2_sel_typ,sel,ofs_);
  end;

procedure free_selector(const sel:smallword);
  var
    es_,bx_:smallword;
  begin
    PhysToUVirt(sel shl 16,0,0,OS2_SELTYPE_FREE,es_,bx_);
  end;

{$EndIf}
{$IfDef DPMI32}
function allocate_selector(var sel:smallword):longint;
  assembler;
  {&Frame-}{&Uses ECX}
  asm
    sub eax,eax
    mov ecx,1
    int $31
    jc @fehler

    mov ecx,[sel]
    mov [ecx],eax
    sub eax,eax
    jmp @ret

  @fehler:
    or eax,$ffff0000

  @ret:
  end;


(* seltype
   $8000

                                                        *)


function set_selector(const sel:smallword;const base,length,seltype_not,seltype_or:longint;const os2_sel_typ:byte):longint;
  assembler;
  {&Frame-}{&Uses EBX,ECX,EDX,EDI}
  var
    ldt_sel_descriptor:array[0..7] of byte;
  asm
    mov eax,$0007
    movzx ebx,[sel]
    mov dx,[base+0].smallword
    mov cx,[base+2].smallword
    int $31
    jc @fehler

    mov eax,$0008
    //movzx bx,[sel]
    mov dx,[length+0].smallword
    mov cx,[length+2].smallword
    int $31
    jc @fehler

    mov eax,$000b               // get descriptor
    //movzx ebx,[sel]
    lea edi,ldt_sel_descriptor
    int $31
    jc @fehler

    mov eax,[seltype_not]
    not eax
    and [edi+5],ax              // bit 40..55
    mov eax,[seltype_or]
    or [edi+5],ax               // bit 40..55

    mov eax,$000c               // set descriptor
    //movzx ebx,[sel]
    //lea edi,ldt_sel_descriptor
    int $31
    jc @fehler

    sub eax,eax
    jmp @ret

  @fehler:
    or eax,$ffff0000

  @ret:
  end;

procedure free_selector(const sel:smallword);
  assembler;
  {&Frame-}{&Uses EAX,EBX}
  asm
    mov eax,$0001
    mov bx,[sel]
    int $31
  end;
{$EndIf DPMI32}

{$IfDef DPMI32}
function im_ersten_mb(const l:longint):boolean;
  begin
    im_ersten_mb:=(l>=0) and (l<=$fffff);
  end;
{$EndIf}

{$IfDef DPMI32}
procedure schreibe(const s:string);
  var
    p:word;
  begin
    for p:=1 to Length(s) do
      begin
        code16feld[code16pos]:=Ord(s[p]);
        Inc(code16pos);
      end;
  end;

function smallword_zu_str2(const w:smallword):string;
  begin
    smallword_zu_str2:=Chr(Lo(w))+Chr(Hi(w));
  end;

procedure push_smallword(const w:smallword);
  begin
    schreibe(#$66#$68+smallword_zu_str2(w));
    Inc(para_stack_used);
  end;
{$EndIf DPMI32}

{$IfDef OS2}
procedure push_smallword(const w:smallword);
  begin
    Inc(para_stack_used);
    stack_array[para_stack_used]:=w;
  end;
{$EndIf OS2}


procedure push_longint(const l:longint);
  begin
    push_smallword(l shr 16);
    push_smallword(l and $ffff);
  end;

procedure push_PnP_BIOS_writable_segment_selector;
  begin
    push_smallword(bios_sel.sel);
  end;

procedure push_read_writable_selector_for_ESCD;
  begin
    push_smallword(escd_sel.sel);
  end;

procedure push_longint1;
  begin
    {$IfDef OS2}
    push_longint(Ofs(data_longint_1_1616^));
    data_buffer_used:=Max(data_buffer_used,4);
    {$EndIf OS2}
    {$IfDef DPMI32}
    push_smallword(data_sel.sel);
    push_smallword(0);
    {$EndIf DPMI32}
  end;

procedure push_longint2;
  begin
    {$IfDef OS2}
    push_longint(Ofs(data_longint_2_1616^));
    data_buffer_used:=Max(data_buffer_used,8);
    {$EndIf OS2}
    {$IfDef DPMI32}
    push_smallword(data_sel.sel);
    push_smallword(4);
    {$EndIf DPMI32}
  end;

procedure push_longint3;
  begin
    {$IfDef OS2}
    push_longint(Ofs(data_longint_3_1616^));
    data_buffer_used:=Max(data_buffer_used,12);
    {$EndIf OS2}
    {$IfDef DPMI32}
    push_smallword(data_sel.sel);
    push_smallword(8);
    {$EndIf DPMI32}
  end;

procedure push_longint_buffer;
  begin
    {$IfDef OS2}
    push_longint(Ofs(data_buffer1616^));
    data_buffer_used:=Max(data_buffer_used,$ffff);
    {$EndIf OS2}
    {$IfDef DPMI32}
    push_smallword(data_sel.sel);
    push_smallword(12);
    {$EndIf DPMI32}
  end;

procedure map_phys_linear(const phys:longint;var len:longint;var lin:longint);
  begin
    {$IfDef OS2}
    // phys->phys
    lin:=phys;
    {$EndIf OS2}
    {$IfDef DPMI32}
    if im_ersten_mb(phys) then
      begin
        lin:=phys;
        Exit;
      end;

    if (phys and $ffff0000)=$ffff0000 then
      len:=Min($e000,len);

    lin:=map_physical_to_linear(phys,len);

    if lin=-1 then
      begin
        WriteLn(#7'Map $',Int2Hex(phys,8),',$',Int2Hex(len,8),' failed !');
        Halt(8);
      end;
    {$EndIf}
  end;

procedure neuanfang_aufruf;
  begin
    {$IfDef DPMI32}
    code16pos:=0;
    {$EndIf DPMI32}
    para_stack_used:=0;
    {$IfDef OS2}
    data_buffer_used:=0;
    {$EndIf OS2}
    FillChar(data_buffer,SizeOf(data_buffer),0)
  end;


{$IfDef OS2}
procedure open_biospnp;
  var
    f000_sel            :prot_mode_ptr_typ;
  begin
    if SysFileOpen('BIOS$PNP',0,bios_pnp)<>0 then
      begin
        WriteLn('device driver BIOS_PNP.SYS not found.');
        WriteLn('try the DOS version (pnp32_d.cmd) ...');
        Halt(255);
      end;

    with f000_sel do
      begin
        ofs:=0;
        allocate_selector(sel);
        set_selector(sel,$000f0000,$10000,
                     descriptor_access,
                     descriptor_access_data_readwrite,
                     OS2_SELTYPE_R3DATA);
      end;

    asm
      push ds
        pushad
          mov ds,[f000_sel].sel
          mov esi,[f000_sel].ofs
          mov edi,offset memf0000
          mov ecx,16*1024 // *4
          cld
          rep movsd
        popad
      pop ds
    end;

    free_selector(f000_sel.sel);
  end;
{$EndIf OS2}


var
  lin_cs  :longint=0;
  lin_bios:longint=0;
  lin_escd:longint=0;

procedure setup_pnp_callcode(const cs,eip,phys_bios:longint);
  var
    len:longint;
  begin
    with entrypoint do
      begin
        len:=$10000;
        map_phys_linear(cs,len,lin_cs);

        ofs:=eip;
        allocate_selector(sel);
        set_selector(sel,lin_cs,len,
                     descriptor_default_operation_size   +descriptor_access             ,
                     descriptor_default_operation_size_16+descriptor_access_execute_read,
                     OS2_SELTYPE_R2CODE);
      end;

    with bios_sel do
      begin
        len:=$10000;
        map_phys_linear(phys_bios,len,lin_bios);

        ofs:=0;
        allocate_selector(sel);
        set_selector(sel,lin_bios,len,
                     descriptor_access,
                     descriptor_access_data_readwrite,
                     OS2_SELTYPE_R2DATA);
      end;

    {$IfDef DPMI32}
    with stack16prot do
      begin
        ofs:=stacksize-$80; (* Systemsoft...*)
        allocate_selector(sel);
        set_selector(sel,System.Ofs(pnp_stack),stacksize,
                     descriptor_default_operation_size   +descriptor_access               ,
                     descriptor_default_operation_size_16+descriptor_access_data_readwrite,
                     OS2_SELTYPE_R2DATA);
      end;

    with code16prot do
      begin

        ofs:=0;

        allocate_selector(sel);

        set_selector(sel,System.Ofs(code16feld),High(code16feld),
                     descriptor_default_operation_size   +descriptor_access             ,
                     descriptor_default_operation_size_32+descriptor_access_execute_read,
                     OS2_SELTYPE_R2CODE);
      end;
    {$EndIf DPMI32}

    with data_sel do
      begin
        ofs:=0;
        allocate_selector(sel);
        set_selector(sel,System.Ofs(data_buffer),High(data_buffer),
                     descriptor_access               ,
                     descriptor_access_data_readwrite,
                     OS2_SELTYPE_R2DATA);
      end;
  end;

procedure setup_escd_selector;
  var
    len:longint;
  begin

    with escd_sel do
      begin
        len:=$10000;
        map_phys_linear(physaddr,len,lin_escd);

        ofs:=0;
        allocate_selector(sel);
        set_selector(sel,lin_escd,len,
                     descriptor_access              ,
                     descriptor_access_data_readonly, // sp„ter vielleicht auch schreiben
                     OS2_SELTYPE_R2CODE);
      end;

  end;

procedure release_pnp_code;
  begin
    free_selector(entrypoint.sel);
    free_selector(bios_sel.sel);
    {$IfDef DPMI32}
    free_selector(stack16prot.sel);
    free_selector(code16prot.sel);
    {$EndIf DPMI32}
    free_selector(data_sel.sel);

    {$IFNDEF OS2}
    if not im_ersten_mb(lin_cs) then
      unmap_linear(lin_cs);
    if im_ersten_mb(lin_bios) then
      unmap_linear(lin_bios);
    {$EndIf OS2}

    {$IfDef OS2}
    SysFileClose(bios_pnp);
    {$EndIf OS2}
  end;

{$IfDef DPMI32}
function call_entrypoint(const function_number:smallword):word;
  begin
    push_smallword(function_number);

    (* call entrypoint *)
    schreibe(#$66#$9a+smallword_zu_str2(entrypoint.ofs)+smallword_zu_str2(entrypoint.sel));
    (* pop from stack *)
    schreibe(#$83#$c4+Chr(Lo(para_stack_used*2)));
    (* return far(32) *)
    schreibe(#$cb);

    asm {&Alters EAX}
      mov stack_pascal.sel,ss
      mov stack_pascal.ofs,esp
      lss esp,stack16prot
      call [code16prot]
      lss esp,stack_pascal
      movzx eax,ax
      mov [@result],eax
    end;

  end;
{$EndIf DPMI32}

{$IfDef OS2}
{&Orgname+}
function goto_32_16(const parameter_array:pointer;const parameter_count:smallword):smallword;external;
  {$L L3L2\L3L2.OBJ }
{&Orgname-}

function call_entrypoint(const function_number:smallword):word;
  var
    para:pointer;
  begin

    push_smallword(function_number);
    push_smallword(entrypoint.ofs);
    push_smallword(entrypoint.sel);

    para:=@stack_array;
    FlatToSel(para);
    call_entrypoint:=goto_32_16(para,para_stack_used);
  end;
{$EndIf OS2}


function Get_Number_of_System_Device_Nodes;
  begin
    neuanfang_aufruf;
    data_longint_1^:=0;
    data_longint_2^:=0;
    push_PnP_BIOS_writable_segment_selector;
    push_longint1;
    push_longint2;
    Get_Number_of_System_Device_Nodes:=call_entrypoint($00);
    size_of_largest_device_node:=data_longint_1^;
    number_of_device_nodes:=data_longint_2^;

    buffersize:=size_of_largest_device_node;
  end;

// $01
function Get_System_Device_Node;
  begin
    neuanfang_aufruf;
    push_PnP_BIOS_writable_segment_selector;
    push_smallword(control_flag);
    push_longint_buffer;
    data_longint_1^:=node_number_or_handle;
    push_longint1;
    Get_System_Device_Node:=call_entrypoint($01);
    node_number_or_handle:=data_longint_1^;
    Move(data_buffer32^,buffer,buffersize);
  end;

// $0a
function Get_Statically_Allocated_Resource_Information;
  const
    buffersize=8192;
  begin
    neuanfang_aufruf;
    push_PnP_BIOS_writable_segment_selector;
    push_longint_buffer;
    Get_Statically_Allocated_Resource_Information:=call_entrypoint($0a);
    Move(data_buffer32^,buffer,buffersize);
  end;

// $40
function Get_Plug_and_Play_ISA_Configuration_Structure;
  const
    buffersize=1+1+2+2;
  begin
    neuanfang_aufruf;
    push_PnP_BIOS_writable_segment_selector;
    push_longint_buffer;
    Get_Plug_and_Play_ISA_Configuration_Structure:=call_entrypoint($40);
    Move(data_buffer32^,buffer,buffersize);
  end;

// $41
function Get_Extended_System_Configuration_Data_Info;
  begin
    neuanfang_aufruf;
    data_longint_1^:=0;
    data_longint_2^:=0;
    data_longint_3^:=0;
    push_PnP_BIOS_writable_segment_selector;
    push_longint1;
    push_longint2;
    push_longint3;
    Get_Extended_System_Configuration_Data_Info:=call_entrypoint($41);
    nonvolatile_storage         :=data_longint_3^; (* 16 *)
    ESCD_allocated              :=data_longint_2^; (* 16 *)
    base_address_of_NV_storage  :=data_longint_1^; (* 32 *)
  end;

// $42
function Read_Extended_System_Configuration_Data;
  const
    buffersize=ecsdsize;
  begin
    neuanfang_aufruf;
    push_PnP_BIOS_writable_segment_selector;
    setup_escd_selector(addr_ESCD);
    push_read_writable_selector_for_ESCD;
    push_longint_buffer;
    Read_Extended_System_Configuration_Data:=call_entrypoint($42);
    Move(data_buffer32^,buffer,buffersize);
  end;

begin
  {$IfDef OS2}
  FlatToSel(Pointer(data_longint_1_1616));
  FlatToSel(Pointer(data_longint_2_1616));
  FlatToSel(Pointer(data_longint_3_1616));
  FlatToSel(Pointer(data_buffer1616));
  {$EndIf OS2}
end.

