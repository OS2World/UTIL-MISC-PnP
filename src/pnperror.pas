(*&Use32+*)
unit pnperror;

interface

function pnp_error_text(const num:word):string;

implementation

function pnp_error_text(const num:word):string;
  begin (* interr61 *)
    case num of
      $00:pnp_error_text:=' - successful';
      $01:pnp_error_text:=' - boot device resource configuration not saved to nonvolatile memory';
      (*
      $02..$54,
      $60..$7E:
          pnp_error_text:=' - reserved for future warnings [$'+Int2Hex(num,2)+']';*)
      $55:pnp_error_text:=' - unable to read/write Extended System Config Data from nonvolatile mem';
      $56:pnp_error_text:=' - no valid Extended System Configuration Data in nonvolatile storage';
      $59:pnp_error_text:=' - user''s buffer was too small for Extended System Configuration Data';
      $7F:pnp_error_text:=' - device could not be configured statically, but dynamic config succeeded';
      $81:pnp_error_text:=' - unknown function';
      $82:pnp_error_text:=' - unsupported function';
      $83:pnp_error_text:=' - invalid device node (or DMI structure) number/handle';
      $84:pnp_error_text:=' - bad parameter';
      $85:pnp_error_text:=' - failure setting device node'; (* invalid DMI/SMBIOS subfunction *)
      $86:pnp_error_text:=' - no pending events';
      $87:pnp_error_text:=' - system not docked'; (* (SMBIOS) out of space to add data *)
      $88:pnp_error_text:=' - no ISA Plug-and-Play cards installed';
      $89:pnp_error_text:=' - unable to determine docking station''s capabilities';
      $8A:pnp_error_text:=' - undocking sequence failed because system unit does not have a battery';
      $8B:pnp_error_text:=' - resource conflict with a primary boot device';
      $8C:pnp_error_text:=' - buffer provided by user was too small';
      $8D:pnp_error_text:=' - must use ESCD support for specified device';
          (* (SMBIOS) "set" request failed (one or more fields read-only) *)
      $8E:pnp_error_text:=' - message not supported';
      $8F:pnp_error_text:=' - hardware error';
      (* ---SMBIOS v2.1+ --- *)
      $90:pnp_error_text:=' - locking not supported for the GPNV handle';
      $91:pnp_error_text:=' - GPNV already locked';
      $92:pnp_error_text:=' - invalid GPNV lock value';
    else
          (*
          pnp_error_text:=' - unknown error code ['+Int2Hex(num,4)+']';*)
          pnp_error_text:='';
    end;
  end;

end.

