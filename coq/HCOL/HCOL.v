(* Coq defintions for HCOL operator language *)

Require Import Helix.Util.VecUtil.
Require Import Helix.Util.VecSetoid.
Require Import Helix.Util.Misc.
Require Import Helix.Util.FinNat.
Require Import Helix.HCOL.CarrierType.
Require Import Helix.HCOL.HCOLImpl.

Require Import Coq.Arith.Arith.
Require Import Coq.Arith.Plus.
Require Import Coq.Program.Program.
Require Import Coq.Classes.Morphisms.

Require Import Helix.Tactics.HelixTactics.
Require Import Coq.Logic.FunctionalExtensionality.

(* CoRN MathClasses *)
Require Import MathClasses.interfaces.abstract_algebra.
Require Import MathClasses.orders.minmax MathClasses.interfaces.orders.
Require Import MathClasses.implementations.peano_naturals.

Require Import MathClasses.theory.setoids.


Import VectorNotations.
Open Scope vector_scope.

Section WithCarrierA.

  Context `{CAPROPS: CarrierProperties}.

  (* === HCOL operators === *)

  Section HCOL_Language.

    Class HOperator {i o:nat} (op: avector i -> avector o) :=
      op_proper :> Proper ((=) ==> (=)) op.

    Global Instance HOperator_Setoid_Morphism
           {i o op}
           `{H: HOperator i o op}: Setoid_Morphism op.
    Proof.
      split; typeclasses eauto.
    Qed.

    Lemma HOperator_functional_extensionality
          {m n: nat}
          `{HOperator m n f}
          `{HOperator m n g}:
      (∀ v, f v = g v) -> f = g.
    Proof.
      apply ext_equiv_applied_iff.
    Qed.

    Definition HPrepend {i n} (a:avector n)
      : avector i -> avector (n+i)
      := Vapp a.

    Definition HInfinityNorm {i}
      : avector i -> avector 1
      := Vectorize ∘ InfinityNorm.

    Definition HReduction {i}
               (f: CarrierA -> CarrierA -> CarrierA)
               (idv: CarrierA)
      : avector i -> avector 1
      := Vectorize ∘ (Reduction f idv).

    Definition HAppend {i n} (a:avector n)
      : avector i -> avector (i+n)
      := fun x => Vapp x a.

    Definition HVMinus {o}
      : avector (o+o) -> avector o
      := VMinus  ∘ (vector2pair o).

    Definition HBinOp {o}
               (f: FinNat o -> CarrierA -> CarrierA -> CarrierA)
      : avector (o+o) -> avector o
      :=  BinOp f ∘ (vector2pair o).

    Definition HEvalPolynomial {n} (a: avector n): avector 1 -> avector 1
      := Lst ∘ EvalPolynomial a ∘ Scalarize.

    Definition HMonomialEnumerator n
      : avector 1 -> avector (S n)
      := MonomialEnumerator n ∘ Scalarize.

    Definition HChebyshevDistance h
      : avector (h+h) -> avector 1
      := Lst ∘ ChebyshevDistance ∘ (vector2pair h).

    Definition HScalarProd {h}
      : avector (h+h) -> avector 1
      := Lst ∘ ScalarProd ∘ (vector2pair h).

    Definition HInduction (n:nat)
               (f: CarrierA -> CarrierA -> CarrierA)
               (initial: CarrierA)
      : avector 1 -> avector n
      := Induction n f initial ∘ Scalarize.

    Definition HInductor
               (n:nat)
               (f:CarrierA -> CarrierA -> CarrierA)
               (initial: CarrierA)
      : avector 1 -> avector 1
      := Lst ∘ Inductor n f initial ∘ Scalarize.

    Definition HPointwise
               {n: nat}
               (f: FinNat n -> CarrierA -> CarrierA)
               (x: avector n): avector n
      := Vbuild (fun j jd => f (mkFinNat jd) (Vnth x jd)).

    (* Special case of pointwise *)
    Definition HAtomic
               (f: CarrierA -> CarrierA)
               (x: avector 1)
      := [f (Vhead x)].

    Section HCOL_operators.

      Global Instance HPointwise_HOperator
             {n: nat}
             {f: FinNat n -> CarrierA -> CarrierA}
             `{pF: !Proper ((=) ==> (=) ==> (=)) f}:
        HOperator (@HPointwise n f).
      Proof.
        intros x y E.
        apply Vforall2_intro_nth.
        intros j jc.
        unfold HPointwise.
        setoid_rewrite Vbuild_nth.
        apply pF.
        - reflexivity.
        - apply Vnth_proper, E.
      Qed.

      Global Instance HAtomic_HOperator
             (f: CarrierA -> CarrierA)
             `{pF: !Proper ((=) ==> (=)) f}:
        HOperator (HAtomic f).
      Proof.
        intros x y E.
        unfold HAtomic.
        vec_index_equiv i ip.
        simpl.
        dep_destruct i.
        rewrite E.
        reflexivity.
        reflexivity.
      Qed.

      Global Instance HScalarProd_HOperator {n}:
        HOperator (@HScalarProd n).
      Proof.
        intros x y E.
        unfold HScalarProd.
        unfold compose, Lst.
        apply Vcons_single_elim.
        rewrite E.
        reflexivity.
      Qed.

      Global Instance HBinOp_HOperator {o}
             (f: FinNat o -> CarrierA -> CarrierA -> CarrierA)
             `{pF: !Proper ((=) ==> (=) ==> (=) ==> (=)) f}:
        HOperator (@HBinOp o f).
      Proof.
        intros x y E.
        unfold HBinOp.
        unfold compose, Lst, vector2pair.
        rewrite E.
        reflexivity.
      Qed.

      Global Instance HReduction_HOperator {i}
             (f: CarrierA -> CarrierA -> CarrierA)
             `{pF: !Proper ((=) ==> (=) ==> (=)) f}
             (idv: CarrierA):
        HOperator (@HReduction i f idv).
      Proof.
        intros x y E.
        unfold HReduction .
        unfold compose, Lst.
        apply Vcons_single_elim.
        rewrite E.
        reflexivity.
      Qed.

      Global Instance HEvalPolynomial_HOperator {n} (a: avector n):
        HOperator (@HEvalPolynomial n a).
      Proof.
        intros x y E.
        unfold HEvalPolynomial.
        unfold compose, Lst.
        apply Vcons_single_elim.
        rewrite E.
        reflexivity.
      Qed.

      Global Instance HPrepend_HOperator {i n} (a:avector n):
        HOperator (@HPrepend i n a).
      Proof.
        intros x y E.
        unfold HPrepend.
        unfold compose, Lst.
        apply Vcons_single_elim.
        rewrite E.
        reflexivity.
      Qed.

      Global Instance HMonomialEnumerator_HOperator n:
        HOperator (@HMonomialEnumerator n).
      Proof.
        intros x y E.
        unfold HMonomialEnumerator.
        unfold compose, Lst.
        apply Vcons_single_elim.
        rewrite E.
        reflexivity.
      Qed.

      Global Instance HInfinityNorm_HOperator n:
        HOperator (@HInfinityNorm n).
      Proof.
        intros x y E.
        unfold HInfinityNorm.
        unfold compose, Lst.
        apply Vcons_single_elim.
        rewrite E.
        reflexivity.
      Qed.

      Global Instance HInduction_HOperator {n:nat}
             (f: CarrierA -> CarrierA -> CarrierA)
             `{pF: !Proper ((=) ==> (=) ==> (=)) f}
             (initial: CarrierA):
        HOperator (HInduction n f initial).
      Proof.
        intros x y E.
        unfold HInduction.
        unfold compose, Lst.
        apply Vcons_single_elim.
        rewrite E.
        reflexivity.
      Qed.

      Global Instance HInductor_HOperator
             (n:nat)
             (f:CarrierA -> CarrierA -> CarrierA)
             `{pF: !Proper ((=) ==> (=) ==> (=)) f}
             (initial: CarrierA):
        HOperator (HInductor n f initial).
      Proof.
        intros x y E.
        unfold HInductor.
        unfold compose, Lst.
        apply Vcons_single_elim.
        rewrite E.
        reflexivity.
      Qed.


      Global Instance HChebyshevDistance_HOperator h:
        HOperator (HChebyshevDistance h).
      Proof.
        intros x y E.
        unfold HChebyshevDistance.
        unfold compose, Lst, vector2pair.
        apply Vcons_single_elim.
        rewrite E.
        reflexivity.
      Qed.

      Global Instance HVMinus_HOperator h:
        HOperator (@HVMinus h).
      Proof.
        intros x y E.
        unfold HVMinus.
        unfold compose, Lst, vector2pair.
        rewrite E.
        reflexivity.
      Qed.

    End HCOL_operators.
  End HCOL_Language.

  (* We forced to use this instead of usual 'reflexivity' tactics, as currently there is no way in Coq to define 'Reflexive' class instance constraining 'ext_equiv' function arguments by HOperator class *)
  Ltac HOperator_reflexivity := eapply HOperator_functional_extensionality; reflexivity.

  Definition mult_by_nth
             {n:nat}
             (a: vector CarrierA n)
    : FinNat n -> CarrierA -> CarrierA :=
    fun jf x => mult x (Vnth a (proj2_sig jf)).


  Section IgnoreIndex_wrapper.

    (* Wrapper to swap index parameter for HPointwise kernel with given value. 1 stands for arity of 'f'.
  Also restricts domain of 1st natural number to 1 *)
    Definition Fin1SwapIndex {A:Type} {n:nat} (i:FinNat n) (f:FinNat n->A->A) : FinNat 1->A->A := const (f i).

    Global Instance Fin1SwapIndex_proper `{Equiv A} {n:nat}:
      Proper ((=) ==> ((=) ==> (=) ==> (=)) ==> (=) ==> (=) ==> (=)) (@Fin1SwapIndex A n).
    Proof.
      simpl_relation.
      apply H1; assumption.
    Qed.


    (* Wrapper to swap index parameter for HBinOp kernel with given value. 2 stands for arity of 'f'.
  Also restricts domain of 1st natural number to 1 *)
    Definition Fin1SwapIndex2 {A:Type} {n:nat} (i:FinNat n) (f:FinNat n->A->A->A) : FinNat 1->A->A->A := const (f i).

    Global Instance Fin1SwapIndex2_proper `{Equiv A} {n:nat}:
      Proper ((=) ==> ((=) ==> (=) ==> (=) ==> (=)) ==> (=) ==> (=) ==> (=) ==> (=)) (@Fin1SwapIndex2 A n).
    Proof.
      simpl_relation.
      apply H1; assumption.
    Qed.

    (* Wrapper to ignore index parameter for HBinOp kernel. 2 stands for arity of 'f' *)
    Definition IgnoreIndex2 {A B:Type} (f:A->A->A) := const (B:=B) f.

    Lemma IgnoreIndex2_ignores
          `{Equiv A}
          {B: Type}
          (f:A->A->A)
          `{f_mor: !Proper ((=) ==> (=) ==> (=)) f}
      : forall (i0 i1:B),
        (IgnoreIndex2 f) i0 = (IgnoreIndex2 f) i1.
    Proof.
      intros.
      unfold IgnoreIndex2.
      apply f_mor.
    Qed.

    Global Instance IgnoreIndex2_proper `{Ae:Equiv A} `{Ab:Equiv B}:
      (Proper (((=) ==> (=)) ==> (=) ==> (=) ==> (=) ==> (=)) (@IgnoreIndex2 A B)).
    Proof.
      simpl_relation.
      unfold IgnoreIndex2.
      apply H; assumption.
    Qed.

    (* Wrapper to ignore index parameter for HPointwise kernel. *)
    Definition IgnoreIndex {A:Type} {n:nat} (f:A->A) := const (B:=@sig nat (fun i : nat => @lt nat peano_naturals.nat_lt i n)) f.

    Global Instance IgnoredIndex_proper `{Ae:Equiv A} {n:nat}:
      (Proper
         (((=) ==> (=)) ==> (=) ==> (=) ==> (=)) (@IgnoreIndex A n)).
    Proof.
      simpl_relation.
      unfold IgnoreIndex.
      apply H.
      assumption.
    Qed.

  End IgnoreIndex_wrapper.

  Section HCOL_Operator_Lemmas.

    Lemma HPointwise_nth
          {n: nat}
          (f: FinNat n -> CarrierA -> CarrierA)
          {j:nat} {jc:j<n}
          (x: avector n):
      Vnth (HPointwise f x) jc ≡ f (j ↾ jc) (Vnth x jc).
    Proof.
      unfold HPointwise.
      rewrite Vbuild_nth.
      reflexivity.
    Qed.

    Lemma HBinOp_nth
          {o}
          {f: FinNat o -> CarrierA -> CarrierA -> CarrierA}
          {v: avector (o+o)}
          {j:nat}
          (jc: j<o)
          (jc1:j<o+o)
          (jc2: (j+o)<o+o)
      :
        Vnth (@HBinOp o f v) jc ≡ f (mkFinNat jc) (Vnth v jc1) (Vnth v jc2).
    Proof.
      unfold HBinOp, compose, vector2pair, HBinOp, HCOLImpl.BinOp.

      break_let.

      replace t with (fst (Vbreak v)) by crush.
      replace t0 with (snd (Vbreak v)) by crush.
      clear Heqp.

      rewrite Vnth_Vmap2SigIndexed.
      f_equiv.

      rewrite Vnth_fst_Vbreak with (jc3:=jc1); reflexivity.
      rewrite Vnth_snd_Vbreak with (jc3:=jc2); reflexivity.
    Qed.

    Lemma HReduction_nil
          (f: CarrierA -> CarrierA -> CarrierA)
          (idv: CarrierA):
      HReduction f idv [] ≡ [idv].
    Proof.
      reflexivity.
    Qed.


  End HCOL_Operator_Lemmas.

End WithCarrierA.

(* re-declare outside Section *)
Ltac HOperator_reflexivity := eapply HOperator_functional_extensionality; reflexivity.
