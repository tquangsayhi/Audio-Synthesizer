----------------------------------------------------------------------------
-- Title      : Exercise 04 - TXTIO Helper Package
-- Project    : COMP.CE.240 - Logic Synthesis
----------------------------------------------------------------------------
-- File       : txtio_pkg.vhd
-- Author(s)  : T. Szymkowiak
-- Company    : TUNI
-- Created    : 2026-07-20
-- Design     : txtio_pkg
-- Platform   : Simulation
-- Standard   : VHDL'93
----------------------------------------------------------------------------
-- Description: Helper package wrapping std.textio operations used by
--              testbenches to read/write whitespace-separated integers.
--                FUNCTIONS:
--                  txt_io_read  : reads one line from the given file and
--                                 parses num_elems_c integers from it.
--                PROCEDURES:
--                  txt_io_write : writes each element of the given integer
--                                 vector to the file as its own line.
----------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2026-07-20  1.0      TZS     Created
----------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
use std.all; 
use std.textio.all;

package txtio_pkg is

  type integer_vector_t is array (natural range <>) of integer;

  impure function txt_io_read (
    constant input_filepath  : string;
    constant num_elems_c     : natural;
    constant num_rows_c      : natural;
    constant debug           : boolean
  ) return integer_vector_t;

  procedure txt_io_write (
    constant output_filepath : string;
    constant elems_i         : in integer_vector_t;
    constant debug           : boolean
  );

end package txtio_pkg;

----------------------------------------------------------------------------

package body txtio_pkg is

  impure function txt_io_read (
    constant input_filepath : string;
    constant num_elems_c    : natural;
    constant num_rows_c     : natural;
    constant debug          : boolean 
  ) return integer_vector_t is

    variable line_v          : line;
    variable dbg_line_v      : line;
    variable row_vec_v       : integer_vector_t((num_elems_c-1) downto 0);
    variable elem_vec_v      : integer_vector_t((num_elems_c * num_rows_c)-1 downto 0);

    variable elem_idx_hi_v, elem_idx_lo_v : natural   := 0;

    constant LF              : character := character'val(10);

    file file_h : text open read_mode is input_filepath;

  begin -- txt_io_read

    for row_idx in 0 to num_rows_c-1 loop
      
      -- Error check to make sure end of file is not hit too early
      if (endfile(file_h)) then
        report "End of input file reached before specified number of rows have been read!" & 
          LF  & "Last read row: " & integer'image(row_idx)
          severity error;
      end if;
      
      readline(file_h, line_v);    

      for elem_idx in row_vec_v'range loop
        read(line_v, row_vec_v(elem_idx));
      end loop;
        
      elem_idx_lo_v := (row_idx*num_elems_c);
      elem_idx_hi_v := elem_idx_lo_v+num_elems_c;
      
      elem_vec_v(elem_idx_hi_v-1 downto elem_idx_lo_v) := row_vec_v;

    end loop;

    if debug = true then

      elem_idx_lo_v := 0;
      elem_idx_hi_v := 0;

      for row_idx in 0 to num_rows_c-1 loop

        elem_idx_lo_v := (row_idx*num_elems_c);
        elem_idx_hi_v := elem_idx_lo_v+num_elems_c;

        for elem_idx in elem_idx_lo_v to elem_idx_hi_v-1 loop
          write(dbg_line_v, elem_vec_v(elem_idx));

          if elem_idx = elem_idx_hi_v-1 then
            write(dbg_line_v, LF);
            write(dbg_line_v, string'("    "));
          else 
            write(dbg_line_v, string'(" "));
          end if;
        
        end loop;

      end loop;
      
      report 
        LF & "[txt_io_read]:" & 
        LF & "File :"  & input_filepath &
        LF & "Lines: " & integer'image(num_rows_c) &
        LF & "Vals : " & LF & "    " & dbg_line_v.all
        severity note;

      deallocate(dbg_line_v);

    end if;

    return elem_vec_v;

  end function txt_io_read;

  procedure txt_io_write (
    constant output_filepath : string;
    constant elems_i         : in integer_vector_t;
    constant debug           : boolean
  ) is

    variable line_v     : line;
    variable dbg_line_v : line;

    variable num_rows_v : integer := 0;

    constant LF : character := character'val(10);

    file file_h : text open write_mode is output_filepath;

  begin -- txt_io_write

    for elem_idx in 0 to elems_i'high loop
      write(line_v, elems_i(elem_idx));
      writeline(file_h, line_v);
    end loop;

    if debug = true then
      
      for elem_idx in 0 to elems_i'high loop
        write(dbg_line_v, elems_i(elem_idx));
        write(dbg_line_v, LF);
        write(dbg_line_v, string'("    "));
        num_rows_v := num_rows_v + 1;
      end loop;

      
      report 
        LF & "[txt_io_read]:" & 
        LF & "File :"  & output_filepath &
        LF & "Lines: " & integer'image(num_rows_v) &
        LF & "Vals : " & LF & "    " & dbg_line_v.all
        severity note;

      deallocate(dbg_line_v);

    end if;

  end procedure txt_io_write;

end package body txtio_pkg;
