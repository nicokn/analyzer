(** Structures for the querying subsystem. *)

open Cil
open Deriving.Cil
open Pretty

module GU = Goblintutil
module ID = IntDomain.FlatPureIntegers
module BD = IntDomain.Booleans
module LS = SetDomain.ToppedSet (Lval.CilLval) (struct let topname = "All" end)
module TS = SetDomain.ToppedSet (Basetype.CilType) (struct let topname = "All" end)
module PS = SetDomain.ToppedSet (Exp.LockingPattern) (struct let topname = "All" end)
module LPS = SetDomain.ToppedSet (Printable.Prod (Lval.CilLval) (Lval.CilLval)) (struct let topname = "All" end)

(* who uses this? hopefully it's not in the domain *)
module ES_r = SetDomain.ToppedSet (Exp.Exp) (struct let topname = "All" end)
module ES =
struct
  include ES_r
  include Printable.Std
  include Lattice.StdCousot
  let bot = ES_r.top
  let top = ES_r.bot
  let leq x y = ES_r.leq y x
  let join = ES_r.meet
  let meet x y = ES_r.join x y
end

type t = ExpEq of exp * exp
       | EqualSet of exp
       | MayPointTo of exp
       | ReachableFrom of exp
       | ReachableUkTypes of exp
       | Regions of exp
       | MayEscape of varinfo
       | Priority of string
       | IsPublic of varinfo
       | SingleThreaded
       | IsNotUnique
       | EvalFunvar of exp
       | EvalInt of exp
       | EvalStr of exp
       | EvalLength of exp (* length of an array or string *)
       | BlobSize of exp (* size of a dynamically allocated `Blob pointed to by exp *)
       | PrintFullState
       | CondVars of exp
       | Access of exp * bool * bool * int
       | InInterval of exp * IntDomain.Interval32.t
       | TheAnswerToLifeUniverseAndEverything
[@@deriving to_yojson]

type result = [
  | `Top
  | `Int of ID.t
  | `Str of string
  | `Bool of BD.t
  | `LvalSet of LS.t
  | `ExprSet of ES.t
  | `ExpTriples of PS.t
  | `TypeSet of TS.t
  | `Bot
] [@@deriving to_yojson]

type ask = t -> result

module Result: Lattice.S with type t = result =
struct
  include Printable.Std
  type t = result [@@deriving to_yojson]

  let name () = "query result domain"

  let bot () = `Bot
  let is_bot x = x = `Bot
  let bot_name = "Bottom"
  let top () = `Top
  let is_top x = x = `Top
  let top_name = "Unknown"

  let equal x y =
    match (x, y) with
    | (`Top, `Top) -> true
    | (`Bot, `Bot) -> true
    | (`Int x, `Int y) -> ID.equal x y
    | (`Bool x, `Bool y) -> BD.equal x y
    | (`LvalSet x, `LvalSet y) -> LS.equal x y
    | (`ExprSet x, `ExprSet y) -> ES.equal x y
    | (`ExpTriples x, `ExpTriples y) -> PS.equal x y
    | (`TypeSet x, `TypeSet y) -> TS.equal x y
    | _ -> false

  let hash (x:t) =
    match x with
    | `Int n -> ID.hash n
    | `Bool n -> BD.hash n
    | `LvalSet n -> LS.hash n
    | `ExprSet n -> ES.hash n
    | `ExpTriples n -> PS.hash n
    | `TypeSet n -> TS.hash n
    | _ -> Hashtbl.hash x

  let compare x y =
    let constr_to_int x = match x with
      | `Bot -> 0
      | `Int _ -> 1
      | `Bool _ -> 2
      | `LvalSet _ -> 3
      | `ExprSet _ -> 4
      | `ExpTriples _ -> 5
      | `Str _ -> 6
      | `IntSet _ -> 8
      | `TypeSet _ -> 9
      | `Top -> 100
    in match x,y with
    | `Int x, `Int y -> ID.compare x y
    | `Bool x, `Bool y -> BD.compare x y
    | `LvalSet x, `LvalSet y -> LS.compare x y
    | `ExprSet x, `ExprSet y -> ES.compare x y
    | `ExpTriples x, `ExpTriples y -> PS.compare x y
    | `TypeSet x, `TypeSet y -> TS.compare x y
    | _ -> Pervasives.compare (constr_to_int x) (constr_to_int y)

  let rec show state =
    match state with
    | `Int n ->  ID.show n
    | `Str s ->  s
    | `Bool n ->  BD.show n
    | `LvalSet n ->  LS.show n
    | `ExprSet n ->  ES.show n
    | `ExpTriples n ->  PS.show n
    | `TypeSet n -> TS.show n
    | `Bot -> bot_name
    | `Top -> top_name

  let pretty_diff = Printable.dumb_diff (name ()) show

  let leq x y =
    match (x,y) with
    | (_, `Top) -> true
    | (`Top, _) -> false
    | (`Bot, _) -> true
    | (_, `Bot) -> false
    | (`Int x, `Int y) -> ID.leq x y
    | (`Bool x, `Bool y) -> BD.leq x y
    | (`LvalSet x, `LvalSet y) -> LS.leq x y
    | (`ExprSet x, `ExprSet y) -> ES.leq x y
    | (`ExpTriples x, `ExpTriples y) -> PS.leq x y
    | (`TypeSet x, `TypeSet y) -> TS.leq x y
    | _ -> false

  let join x y =
    try match (x,y) with
      | (`Top, _)
      | (_, `Top) -> `Top
      | (`Bot, x)
      | (x, `Bot) -> x
      | (`Int x, `Int y) -> `Int (ID.join x y)
      | (`Bool x, `Bool y) -> `Bool (BD.join x y)
      | (`LvalSet x, `LvalSet y) -> `LvalSet (LS.join x y)
      | (`ExprSet x, `ExprSet y) -> `ExprSet (ES.join x y)
      | (`ExpTriples x, `ExpTriples y) -> `ExpTriples (PS.join x y)
      | (`TypeSet x, `TypeSet y) -> `TypeSet (TS.join x y)
      | _ -> `Top
    with IntDomain.Unknown -> `Top

  let meet x y =
    try match (x,y) with
      | (`Bot, _)
      | (_, `Bot) -> `Bot
      | (`Top, x)
      | (x, `Top) -> x
      | (`Int x, `Int y) -> `Int (ID.meet x y)
      | (`Bool x, `Bool y) -> `Bool (BD.meet x y)
      | (`LvalSet x, `LvalSet y) -> `LvalSet (LS.meet x y)
      | (`ExprSet x, `ExprSet y) -> `ExprSet (ES.meet x y)
      | (`ExpTriples x, `ExpTriples y) -> `ExpTriples (PS.meet x y)
      | (`TypeSet x, `TypeSet y) -> `TypeSet (TS.meet x y)
      | _ -> `Bot
    with IntDomain.Error -> `Bot

  let widen x y =
    try match (x,y) with
      | (`Top, _)
      | (_, `Top) -> `Top
      | (`Bot, x)
      | (x, `Bot) -> x
      | (`Int x, `Int y) -> `Int (ID.widen x y)
      | (`Bool x, `Bool y) -> `Bool (BD.widen x y)
      | (`LvalSet x, `LvalSet y) -> `LvalSet (LS.widen x y)
      | (`ExprSet x, `ExprSet y) -> `ExprSet (ES.widen x y)
      | (`ExpTriples x, `ExpTriples y) -> `ExpTriples (PS.widen x y)
      | (`TypeSet x, `TypeSet y) -> `TypeSet (TS.widen x y)
      | _ -> `Top
    with IntDomain.Unknown -> `Top

  let narrow x y =
    match (x,y) with
    | (`Int x, `Int y) -> `Int (ID.narrow x y)
    | (`Bool x, `Bool y) -> `Bool (BD.narrow x y)
    | (`LvalSet x, `LvalSet y) -> `LvalSet (LS.narrow x y)
    | (`ExprSet x, `ExprSet y) -> `ExprSet (ES.narrow x y)
    | (`ExpTriples x, `ExpTriples y) -> `ExpTriples (PS.narrow x y)
    | (`TypeSet x, `TypeSet y) -> `TypeSet (TS.narrow x y)
    | (x,_) -> x

  let printXml f x = BatPrintf.fprintf f "<value>\n<data>%s\n</data>\n</value>\n" (Goblintutil.escape (show x))
end
