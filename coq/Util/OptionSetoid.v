Require Import Coq.Classes.RelationClasses.

Require Import MathClasses.interfaces.canonical_names.
Require Import MathClasses.misc.util.

Require Import ExtLib.Structures.Monads.
Require Import ExtLib.Data.Monads.OptionMonad.

Require Import CoLoR.Util.Relation.RelUtil.

Require Import Helix.Tactics.HelixTactics.

Global Instance option_Equiv {T:Type} `{Te:Equiv T}:
  Equiv (option T) := @opt_r T Te.

Global Instance option_Equivalence  `{Te: Equiv T} `{H: Equivalence T Te}
  : Equivalence (@option_Equiv T Te).
Proof.
  split.
  - apply opt_r_refl, H.
  - apply opt_r_sym, H.
  - apply opt_r_trans, H.
Qed.

Lemma Some_inj_eq {A:Type}:
  forall (a b:A), a ≡ b <-> Some a ≡ Some b.
Proof.
  intros a b.
  split; intros H.
  -
    f_equiv.
    apply H.
  -
    inversion H.
    auto.
Qed.

Lemma Some_inj_equiv `{E: Equiv A}:
  forall (a b:A), a = b <-> Some a = Some b.
Proof.
  intros a b.
  split; intros H.
  -
    f_equiv.
    apply H.
  -
    inversion H.
    auto.
Qed.

Global Instance Some_proper `{Equiv A}:
  Proper ((=) ==> (=)) (@Some A).
Proof.
  intros a b E.
  apply Some_prop, E.
Qed.

Ltac some_none :=
  let H' := fresh in
  match goal with
  | [H: Some _ = None |- _ ] => inversion H
  | [H: None = Some _ |- _ ] => inversion H
  | [H: Some _ ≡ None |- _ ] => inversion H
  | [H: None ≡ Some _ |- _ ] => inversion H
  | [ |- Some _ ≠ None ] => intros H'; inversion H'
  | [ |- None = None ] => reflexivity
  | [ |- None ≡ None ] => reflexivity
  | [ |- Some ?a = Some ?a] => reflexivity
  | [ |- Some ?a ≡ Some ?a] => reflexivity
  end.

Ltac some_inv :=
  match goal with
  | [H: Some ?A ≡ Some ?b |- _ ] => inversion H; clear H
  | [H: Some ?A = Some ?b |- _ ] => apply Some_inj_equiv in H
  end.

Ltac some_apply :=
  match goal with
  | [H: ?a = ?b |- Some ?a = Some ?b] => apply Some_inj_equiv in H; apply H
  | [H: Some ?a = Some ?b |- ?a = ?b] => apply Some_inj_equiv; apply H
  end.

Lemma Equiv_to_opt_r {A:Type} {a b: option A} `{Ae: Equiv A}:
  a = b -> RelUtil.opt_r Ae a b.
Proof.
  intros H.
  destruct a, b; try some_none; constructor.
  some_inv.
  apply H.
Qed.

Global Instance liftM_option_proper `{Ae:Equiv A} `{Be: Equiv B}:
  Proper (((=) ==> (=)) ==> (=) ==> (=)) (@liftM option Monad_option A B).
Proof.
  intros f f' Ef a a' Ea.
  simpl.
  destruct a, a'; try some_none; auto.
  -
    f_equiv.
    apply Ef.
    inversion Ea.
    auto.
  -
    apply opt_r_None.
Qed.

Lemma Option_equiv_eq {A: Type} {a b: option A} `{Ae: Equiv A} `{Ar: Equivalence A Ae}:
  (a ≡ b) -> (a = b).
Proof.
  intros H.
  rewrite H.
  reflexivity.
Qed.

Lemma None_equiv_eq
      {A: Type}
      `{Ae: Equiv A}
      `{Aee: Equivalence A Ae}
      {x: option A}:
  x ≡ None <-> x = None.
Proof.
  split.
  -
    intros H.
    rewrite H.
    reflexivity.
  -
    intros H.
    inversion H.
    reflexivity.
Qed.

Lemma is_Some_ne_None `(x : option A) :
  is_Some x ↔ x ≢ None.
Proof.
  destruct x; intros; crush.
Qed.

Fact equiv_Some_is_Some `{Equiv A} (x:A) (y: option A):
  (y = Some x) -> is_Some y.
Proof.
  dep_destruct y.
  -
    crush.
  -
    intros H0.
    some_none.
Qed.

(* In monadic world `(f >=> g) ∘ Some` *)
Definition option_compose
           {A B C: Type}
           (f: B → option C)
           (g: A → option B): A → option C
  := fun x =>
       match g x with
       | None => None
       | Some y => f y
       end.

Global Instance option_compose_proper
       {A B C: Type}
       `{Ae: Equiv A} `{Equivalence A Ae}
       `{Be: Equiv B} `{Equivalence B Be}
       `{Ce: Equiv C} `{Equivalence C Ce}:
  Proper (
      (((@equiv B Be) ==> (@option_Equiv C Ce))
         ==>
         ((@equiv A Ae) ==> (@option_Equiv B Be))
         ==>
         (=)
         ==>
         (@option_Equiv C Ce))) (option_compose).
Proof.
  intros f f' Ef g g' Eg x x' E.
  unfold option_compose, option_Equiv.
  repeat break_match;
    apply Option_equiv_eq in Heqo;
    apply Option_equiv_eq in Heqo0;
    setoid_replace (g x) with (g' x') in Heqo by apply Eg, E;
    rewrite Heqo in Heqo0; try some_none.
  -
    some_inv.
    apply Ef, Heqo0.
  -
    reflexivity.
Qed.