(** Public API module *)

(** Re-export of internal compute module *)
module Compute : module type of Internal

(** Alias for backward compatibility *)
module Legacy : module type of Internal

(** Another way to write module aliases - multi-line *)
module Compat : sig
  (** @inline *)
  include module type of Internal
end

(** Single-line version of include alias *)
module SingleLineCompat : sig include module type of Internal end