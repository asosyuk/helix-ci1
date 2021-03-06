Require Import Coq.Strings.String.
Require Import Coq.Lists.List.

Require Import Helix.Util.Misc.

Require Import Vellvm.Syntax.LLVMAst.

Require Import Flocq.IEEE754.Binary.
Require Import Coq.Numbers.BinNums. (* for Z scope *)
Require Import Coq.ZArith.BinInt.
From Coq Require Import ZArith.

Require Import ExtLib.Structures.Monads.

Require Import Ceres.CeresString.

Import ListNotations.
Import MonadNotation.
Open Scope monad_scope.

Set Implicit Arguments.
Set Strict Implicit.

(* Placeholder section for config variables. Probably should be a
module in future *)
Section Config.
  Definition IntType := TYPE_I 64%N.
  Definition PtrAlignment := 16%Z.
  Definition ArrayPtrParamAttrs := [ PARAMATTR_Align PtrAlignment; PARAMATTR_Nonnull ].
End Config.

Definition string_of_raw_id (r:raw_id): string
:= match r with
   | Name s => s
   | Anon _ => "#ANON"
   | Raw  _ => "#RAW"
   end.

Definition string_of_ident (i:ident) : string :=
  match i with
  | ID_Global n => (append "Global " (string_of_raw_id n))
  | ID_Local  n => (append "Local " (string_of_raw_id n))
  end.

Fixpoint string_of_IRType (t: typ) :=
  match t with
  | TYPE_I 64%N => "int64"
  | TYPE_Double => "float64"
  | TYPE_Array n TYPE_Double => append "float64[" ((Ceres.CeresString.string_of_N n) ++ "]")
  | TYPE_Pointer p => append "*" (string_of_IRType p)
  | _ => "#INVALID"
  end.

Definition string_of_Γ (Γ:list (ident * typ)) : string
  := "[" ++ String.concat ", " (List.map
                                  (fun '(n,t) =>
                                     append (string_of_ident n)
                                            (":" ++(string_of_IRType t))
                                  )
                           Γ) ++ "]".
