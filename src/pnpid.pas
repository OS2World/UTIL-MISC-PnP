(*&Use32+*)
unit pnpid;

interface

type
  string07              =string[7];

const
  Unrecognised_PnP_ID='Unrecognised PnP ID!';

procedure load_pnpid_txt;
function search_pnpid(const id:string07):string;
procedure free_pnpid_txt;

implementation

uses
  Objects;

var
  pnp_id_list           :pStringCollection;

procedure load_pnpid_txt;
  var
    pnp_f               :text;
    line                :string;
    z                   :word;
    pnpid_txt_path      :string;

  begin
    FileMode:=$40; (* deny none, read only *)

    pnpid_txt_path:=ParamStr(0);
    while (pnpid_txt_path<>'')
      and (not (pnpid_txt_path[Length(pnpid_txt_path)] in ['\','/'])) do
        Dec(pnpid_txt_path[0]);
    pnpid_txt_path:=pnpid_txt_path+'pnpid.txt';
    Assign(pnp_f,pnpid_txt_path);
    {$I-}
    Reset(pnp_f);
    {$I+}

    if IOResult<>0 then
      begin
        Assign(pnp_f,'pnpid.txt');
        {$I-}
        Reset(pnp_f);
        {$I+}
      end;

    if IOResult<>0 then
      begin
        WriteLn('Failed to to load data file pnpid.txt.');
        Halt(1);
      end;

    pnp_id_list:=New(pStringCollection,Init(1000,100));

    while not Eof(pnp_f) do
      begin

        ReadLn(pnp_f,line);

        if (line='') or (line[1] in [';',' ',#9]) then
          Continue;

        if not (line[8] in [' ',#9]) then
          begin
            WriteLn('Syntax error in pmpid.txt.');
            WriteLn('Line: "',line,'"');
            Halt(255);
          end;

        for z:=1 to 7 do
          line[z]:=UpCase(line[z]);

        line[8]:=#9;

        if search_pnpid(Copy(line,1,7))<>Unrecognised_PnP_ID then
          begin
            WriteLn('Double definition of ',Copy(line,1,7),':');
            WriteLn('  first: ',search_pnpid(Copy(line,1,7)));
            WriteLn('  now  : ',Copy(line,9,255));
            Halt(255);
          end;

        pnp_id_list^.Insert(NewStr(line));

      end;

    Close(pnp_f);

  end;


function search_pnpid(const id:string07):string;

  function pnpid_match(const item:{pchar}string):boolean; far;
    begin
      {pnpid_match:=(StrLComp(item,@id[1],7)=0);}
      pnpid_match:=(Copy(item,1,7)=id);
    end;

  var
    found               :^string;
  begin
    with pnp_id_list^ do
      begin
        found:=FirstThat(@pnpid_match);
        if found=nil then
          search_pnpid:='Unrecognised PnP ID!'
        else
          search_pnpid:=Copy(found^,9,255);
      end;
  end;


procedure free_pnpid_txt;
  begin
    pnp_id_list^.Done;
    Dispose(pnp_id_list);
  end;


end.

