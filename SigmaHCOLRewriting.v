
Require Import Spiral.
Require Import SVector.
Require Import HCOL.
Require Import SigmaHCOL.
Require Import HCOLSyntax.

Require Import Arith.
Require Import Compare_dec.
Require Import Coq.Arith.Peano_dec.
Require Import Program. 

Require Import CpdtTactics.
Require Import CaseNaming.
Require Import Coq.Logic.FunctionalExtensionality.

(* CoRN MathClasses *)
Require Import MathClasses.interfaces.abstract_algebra MathClasses.interfaces.orders.
Require Import MathClasses.orders.minmax MathClasses.orders.orders MathClasses.orders.rings.
Require Import MathClasses.theory.rings MathClasses.theory.abs.

(*  CoLoR *)
Require Import CoLoR.Util.Vector.VecUtil.
Import VectorNotations.

Section SigmaHCOLRewriting.
  Context

    `{Ae: Equiv A}
    `{Az: Zero A} `{A1: One A}
    `{Aplus: Plus A} `{Amult: Mult A} 
    `{Aneg: Negate A}
    `{Ale: Le A}
    `{Alt: Lt A}
    `{Ato: !@TotalOrder A Ae Ale}
    `{Aabs: !@Abs A Ae Ale Az Aneg}
    `{Asetoid: !@Setoid A Ae}
    `{Aledec: !∀ x y: A, Decision (x ≤ y)}
    `{Aeqdec: !∀ x y, Decision (x = y)}
    `{Altdec: !∀ x y: A, Decision (x < y)}
    `{Ar: !Ring A}
    `{ASRO: !@SemiRingOrder A Ae Aplus Amult Az A1 Ale}
    `{ASSO: !@StrictSetoidOrder A Ae Alt}
  .

  Add Ring RingA: (stdlib_ring_theory A).
  
  Open Scope vector_scope.


  (*
Motivating example:

BinOp(2, Lambda([ r4, r5 ], sub(r4, r5)))

-->

ISumUnion(i3, 2,
  ScatHUnion(2, 1, i3, 1) o
  BinOp(1, Lambda([ r4, r5 ], sub(r4, r5))) o
  GathH(4, 2, i3, 2)
)

    BinOp := (self, o, opts) >> When(o.N=1, o, let(i := Ind(o.N),
        ISumUnion(i, i.range, OLCompose(
        ScatHUnion(o.N, 1, i, 1),
        BinOp(1, o.op),
        GathH(2*o.N, 2, i, o.N)
        )))),

   *)

  Lemma cast_vector_operator_OK_OK: forall i0 i1 o0 o1 (v: vector A i1)
                                      (op: vector A i0 → svector A o0)
    ,
      (i0 ≡ i1 /\ o0 ≡ o1) -> is_OK ((cast_vector_operator
                                      i0 o0
                                      i1 o1
                                      (OK ∘ op)) v).
  Proof.
    intros.
    destruct H as [Hi Ho].
    rewrite <- Ho. clear o1 Ho.
    revert op.
    rewrite Hi. clear i0 Hi.
    intros.

    unfold compose.
    set (e := (λ x : vector A i1, @OK (vector (option A) o0) (op x))).

    assert(is_OK (e v)).
    unfold e. simpl. trivial.
    revert H.
    generalize dependent e. clear op.
    intros.

    rename i1 into i.
    rename o0 into o.
    (* here we arrived to more generic form of the lemma, stating that is_OK property is preserved by 'cast_vector_operator *)

    unfold cast_vector_operator.
    destruct (eq_nat_dec o o), (eq_nat_dec i i); try congruence.

    compute.
    destruct e0.
    dep_destruct e1.
    auto.
  Qed.
  
  Lemma BinOpIsDense: forall o st
                        (f:A->A->A) `{pF: !Proper ((=) ==> (=) ==> (=)) f}
                        (x: svector A (o+o)),
      svector_is_dense x -> 
      is_OK (evalSigmaHCOL st (SHOBinOp o f) x).
  Proof.
    intros. simpl.
    unfold evalBinOp.
    apply dense_casts_OK in H.
    destruct (try_vector_from_svector x).
    apply cast_vector_operator_OK_OK. omega.
    contradiction.
  Qed.
  
  Definition ASub: A -> A -> A := (plus∘negate).
 
  Global Instance ASub_proper:
    Proper ((=) ==> (=) ==> (=)) (ASub).
  Proof.
    intros a a' aE b b' bE.
    unfold ASub.
    rewrite aE, bE.
    reflexivity.
  Qed.

  Definition op1 := SHOBinOp 2 ASub.
  Definition vari := AValue (Var "i").
  Definition c2 := AConst 2.
  Definition c0 := AConst 0.
  
  Definition op2 :=
    SHOISumUnion (Var "i") c2
                 (SHOCompose _ _
                             (SHOScatHUnion (o:=2) vari c2)
                             (SHOCompose _ _ 
                                         (SHOBinOp 1 ASub)
                                         (SHOGathH (i:=4) (o:=2) vari c2))).

  Lemma testOp2Op1: forall (st : state) (x : vector (option A) (2 + 2)),
      svector_is_dense x -> evalSigmaHCOL st op1 x = evalSigmaHCOL st op2 x.
  Proof.
    intros.
    unfold equiv, maybeError_equiv, op1.
    assert (op1OK: is_OK (evalSigmaHCOL st (SHOBinOp 2 ASub) x)) by (apply BinOpIsDense; assumption).

    case_eq (evalSigmaHCOL st (SHOBinOp 2 ASub) x); intros; simpl in H0, op1OK.

    Focus 2.
    rewrite H0 in op1OK.
    contradiction.

     unfold op2.
    
  Qed.
  
  Section SigmaHCOLRewriting.
