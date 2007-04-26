(*
 * ProgramView: program abstraction module for DFA.
 * Copyright (C) 2007
 * Gennadiy Sych, St.Petersburg State University
 * 
 * This software is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License version 2, as published by the Free Software Foundation.
 * 
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * 
 * See the GNU Library General Public License version 2 for more details
 * (enclosed in the file COPYING).
 *)

(** ViewAdapter --- a common signature to translate concrete representation of
    program statements into DFA representation. See DFAEngine for details.
 *)

(** ViewAdapter signature *)
module type Sig =
  sig
    
    (** Type of node representation for the particular algorithm *)
    type nt

    (** Type for statements of original program *)
    type gnt
    
    (** Conversion function *)
    val convert : gnt -> nt

  end

