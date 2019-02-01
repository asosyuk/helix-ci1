(* Memory-based implementations of SHCOL operators *)

Require Import Coq.Arith.PeanoNat.

Require Import Helix.Util.VecUtil.
Require Import Helix.Util.Misc.
Require Import Helix.SigmaHCOL.Rtheta.
Require Import Helix.SigmaHCOL.SVector.
Require Import Helix.SigmaHCOL.IndexFunctions.
Require Import Helix.SigmaHCOL.Memory.

Global Open Scope nat_scope.

Set Implicit Arguments.

Fixpoint avector_to_mem_block' {n} (i:nat) (v:avector n): mem_block
  :=
    match v with
    | Vnil => mem_empty
    | Vcons x xs =>
      mem_add n x (avector_to_mem_block' (S i) xs)
    end.

Definition avector_to_mem_block {n:nat}: (avector n) -> mem_block
  := avector_to_mem_block' 0.

Definition mem_block_to_avector {n} (m: mem_block): option (avector n)
  := vsequence (Vbuild (fun i (ic:i<n) => mem_lookup i m)).

(* HOperator (on dense vector) mapping to memory operator *)
Definition mem_op_of_hop {i o: nat} (op: avector i -> avector o)
  : mem_block -> option mem_block
  := fun x => match mem_block_to_avector x with
           | None => None
           | Some x' => Some (avector_to_mem_block (op x'))
           end.

Section WithFlags.

  Variable fm:Monoid.Monoid RthetaFlags.

  Fixpoint svector_to_mem_block' {n} (i:nat) (v:svector fm n): mem_block
    :=
      match v with
      | Vnil => mem_empty
      | Vcons x xs =>
        match Is_Val_dec x with
        | left _ => mem_add n (WriterMonadNoT.evalWriter x) (svector_to_mem_block' (S i) xs)
        | right _ => svector_to_mem_block' (S i) xs
        end
      end.

  Definition svector_to_mem_block {n:nat}: (svector fm n) -> mem_block
    := svector_to_mem_block' 0.

  Definition mem_block_to_svector {n} (m: mem_block): svector fm n
    := Vbuild (fun i (ic:i<n) =>
                 match mem_lookup i m with
                 | None => mkSZero
                 | Some x => mkValue x
                 end
              ).

  (* SHOperator (on sparse vectors) mapping to memory operator *)
  Definition mem_op_of_op {i o: nat} (op: svector fm i -> svector fm o)
    : mem_block -> option mem_block
    := fun x => Some (svector_to_mem_block (op (mem_block_to_svector x))).

End WithFlags.

(* y[j] := x[i] *)
Definition map_mem_block_elt (x:mem_block) (i:nat) (y:mem_block) (j:nat)
  : option mem_block :=
  match mem_lookup i x with
  | None => None
  | Some v => Some (mem_add j v y)
  end.

(* AKA: "embed" *)
Definition eUnion_mem (b: nat) (x:mem_block): option mem_block :=
  map_mem_block_elt x 0 (mem_empty) b.

(* AKA "pick" *)
Definition eT_mem (b: nat) (x:mem_block): option mem_block :=
  map_mem_block_elt x b (mem_empty) 0.

Fixpoint Gather_mem
         {i o: nat}
         (f: index_map o i)
         (x: mem_block) : option mem_block
  :=
    let i' := ⟦ f ⟧ o in
    let map_one ys := map_mem_block_elt x i' ys o in
    match o return (index_map o i) -> option mem_block with
    | O => fun _ => map_one (mem_empty)
    | S o' => fun f' =>
               match Gather_mem (shrink_index_map_domain f') x with
               | None => None
               | Some ys => map_one ys
               end
    end f.

Fixpoint Scatter_mem_aux
         {i o: nat}
         (j: nat)
         {f: index_map i o}
         (fi: inverse_index_map f)
         (x: mem_block) : option mem_block
  :=
    let o' := inverse_index_f f fi j in
    let map_one ys := map_mem_block_elt x j ys o' in
    match j with
    | O => map_one (mem_empty)
    | S j' => match Scatter_mem_aux j' fi x with
             | None => None
             | Some ys => map_one ys
             end
    end.

Definition Scatter_mem {i o: nat} (f: index_map i o)
  :
    mem_block -> option mem_block
  :=
    Scatter_mem_aux i (build_inverse_index_map f).

Fixpoint IUnion_mem_aux
         {n: nat}
         (j: nat) (jc: j<n)
         (op_family_f: forall k (kc:k<n), mem_block -> option mem_block)
         (x: mem_block) {struct j}: option mem_block :=
  let oy := op_family_f j jc x in
  match j return j<n -> option mem_block with
  | O => fun _ => oy
  | S j' => fun jc' =>
             match oy, IUnion_mem_aux (Nat.lt_succ_l j' n jc') op_family_f x with
             | Some y, Some ys => mem_merge y ys
             | _, _ => None
             end
  end jc.

Definition IUnion_mem
           {n: nat}
           (op_family_f: forall k (kc:k<n), mem_block -> option mem_block)
           (x: mem_block): option mem_block
  :=
    match n as m return n=m -> option mem_block with
    | 0 => fun _ => Some x
    | S n' => fun E => IUnion_mem_aux
                     (eq_ind_r _ (Nat.lt_succ_diag_r n') E)
                     op_family_f x
    end eq_refl.
    end eq_refl.