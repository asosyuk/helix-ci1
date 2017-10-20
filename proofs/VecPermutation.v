
Require Import Coq.Arith.Arith.
Require Export Coq.Vectors.Vector.
Require Import Coq.Program.Equality. (* for dependent induction *)
Require Import Setoid Morphisms.

(* CoLoR: `opam install coq-color`  *)
Require Export CoLoR.Util.Vector.VecUtil.

Open Scope vector_scope.

(* Re-define :: List notation for vectors. Probably not such a good idea *)
Notation "h :: t" := (cons h t) (at level 60, right associativity)
                     : vector_scope.

Import VectorNotations.

Section VPermutation.

  Variable A:Type.

  Inductive VPermutation: forall n, vector A n -> vector A n -> Prop :=
  | vperm_nil: VPermutation 0 [] []
  | vperm_skip {n} x l l' : VPermutation n l l' -> VPermutation (S n) (x::l) (x::l')
  | vperm_swap {n} x y l : VPermutation (S (S n)) (y::x::l) (x::y::l)
  | vperm_trans {n} l l' l'' :
      VPermutation n l l' -> VPermutation n l' l'' -> VPermutation n l l''.

  Local Hint Constructors VPermutation.

  (** Some facts about [VPermutation] *)

  Theorem VPermutation_nil : forall (l : vector A 0), VPermutation 0 [] l -> l = [].
  Proof.
    intros l HF.
    dependent destruction l.
    reflexivity.
  Qed.

  (** VPermutation over vectors is a equivalence relation *)

  Theorem VPermutation_refl : forall {n} (l: vector A n), VPermutation n l l.
  Proof.
    induction l; constructor. exact IHl.
  Qed.

  Theorem VPermutation_sym : forall {n} (l l' : vector A n),
      VPermutation n l l' -> VPermutation n l' l.
  Proof.
    intros n l l' Hperm.
    induction Hperm; auto.
    apply vperm_trans with (l'0:=l'); auto.
  Qed.

  Theorem VPermutation_trans : forall {n} (l l' l'' : vector A n),
      VPermutation n l l' -> VPermutation n l' l'' -> VPermutation n l l''.
  Proof.
    intros n l l' l''.
    apply vperm_trans.
  Qed.

End VPermutation.

Hint Resolve VPermutation_refl vperm_nil vperm_skip.

(* These hints do not reduce the size of the problem to solve and they
   must be used with care to avoid combinatoric explosions *)

Local Hint Resolve vperm_swap vperm_trans.
Local Hint Resolve VPermutation_sym VPermutation_trans.

(* This provides reflexivity, symmetry and transitivity and rewriting
   on morphims to come *)

Instance VPermutation_Equivalence A n : Equivalence (@VPermutation A n) | 10 :=
  {
    Equivalence_Reflexive := @VPermutation_refl A n ;
    Equivalence_Symmetric := @VPermutation_sym A n ;
    Equivalence_Transitive := @VPermutation_trans A n
  }.

Section VPermutation_properties.

  Require Import Sorting.Permutation.

  Variable A:Type.

  Lemma ListVecPermutation {n} {l1 l2} {v1 v2}:
    l1 = list_of_vec v1 ->
    l2 = list_of_vec v2 ->
    Permutation l1 l2 ->
    VPermutation A n v1 v2.
  Proof.
    intros H1 H2 P.
    revert H1 H2.
    dependent induction P.
    -
      intros H1 H2.
      dependent destruction v1; auto.
      dependent destruction v2; auto.
      inversion H1.
    -
      intros H1 H2.
      dependent destruction v1; auto.
      inversion H1.
      dependent destruction v2; auto.
      inversion H1.
      inversion H2.
      subst.
      apply vperm_skip.
      (* apply IHP. *)
  Admitted.

  Theorem VPermutation_middle
          {m n}
          (v1: vector A m)
          (v2:vector A n)
          {a: A}:
    VPermutation _ _ (a :: (Vapp v1 v2)) (Vcast
                                            (Vapp v1 (a :: v2))
                                            (Nat.add_succ_r _ _)
                                         ).
  Proof.
  Admitted.


End VPermutation_properties.
