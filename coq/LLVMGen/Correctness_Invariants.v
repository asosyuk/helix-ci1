Require Import Helix.LLVMGen.Correctness_Prelude.
Require Import Helix.LLVMGen.LidBound.
Require Import Helix.LLVMGen.IdLemmas.
Require Import Helix.LLVMGen.VariableBinding.
Require Import Helix.LLVMGen.StateCounters.
Require Import Helix.LLVMGen.Context.

From Coq Require Import ZArith.

Set Implicit Arguments.
Set Strict Implicit.

Import ListNotations.
Import AlistNotations.
Section WF_IRState.

  (**
     The compiler maintains a sort of typing context named [IRState].
     This typing context should soundly reflect the content of the [evalContext],
     injecting the types from [DSHCOL] to [VIR].
   *)

  Definition getWFType (id : ident) (t: DSHType): typ :=
    match id, t with
    | ID_Local _  , DSHnat   => IntType
    | ID_Global _ , DSHnat   => TYPE_Pointer IntType
    | ID_Local _  , DSHCType => TYPE_Double
    | ID_Global _ , DSHCType => TYPE_Pointer TYPE_Double
    | _           , DSHPtr n => TYPE_Pointer (TYPE_Array (Z.to_N (Int64.intval n)) TYPE_Double)
    end.

  (* True if σ typechecks in Γ *)
  Definition evalContext_typechecks (σ : evalContext) (Γ : list (ident * typ)) : Prop :=
    forall v n, nth_error σ n ≡ Some v ->
           exists id, (nth_error Γ n ≡ Some (id, getWFType id (DSHType_of_DSHVal v))).

  Definition WF_IRState (σ : evalContext) (s : IRState) : Prop :=
    evalContext_typechecks σ (Γ s).

  Lemma evalContext_typechecks_extend:
    ∀ (σ : evalContext) (s1 s1' : IRState) (x : ident * typ) (v : DSHVal),
      Γ s1' ≡ x :: Γ s1 → evalContext_typechecks (v :: σ) (Γ s1') →
      evalContext_typechecks σ (Γ s1).
  Proof.
    intros σ s1 s1' x v H2 H9.
    red. red in H9. intros.
    rewrite H2 in H9. specialize (H9 _ (S n) H). cbn in *.
    apply H9.
  Qed.

  Lemma WF_IRState_lookups :
    forall σ s n v id τ,
      WF_IRState σ s ->
      nth_error (Γ s) n ≡ Some (id, τ) ->
      nth_error σ n ≡ Some v ->
      τ ≡ getWFType id (DSHType_of_DSHVal v).
  Proof.
    intros * WF LU_IR LU_SIGMA.
    apply WF in LU_SIGMA; destruct LU_SIGMA as (id' & LU); rewrite LU in LU_IR; inv LU_IR.
    reflexivity.
  Qed.

  Lemma WF_IRState_one_of_local_type:
    forall σ x τ s n v,
      WF_IRState σ s ->
      nth_error (Γ s) n ≡ Some (ID_Local x,τ) ->
      nth_error σ n ≡ Some v ->
      τ ≡ IntType \/
      τ ≡ TYPE_Double \/
      exists k, τ ≡ TYPE_Pointer (TYPE_Array (Z.to_N (Int64.intval k)) TYPE_Double).
  Proof.
    intros * WF LU LU'.
    eapply WF in LU'; destruct LU' as (id & LU''); rewrite LU in LU''; inv LU''.
    cbn; break_match_goal; eauto.
  Qed.

  Lemma WF_IRState_one_of_global_type:
    forall σ x τ s n v,
      WF_IRState σ s ->
      nth_error (Γ s) n ≡ Some (ID_Global x,τ) ->
      nth_error σ n ≡ Some v ->
      τ ≡ TYPE_Pointer IntType \/
      τ ≡ TYPE_Pointer TYPE_Double \/
      exists k, τ ≡ TYPE_Pointer (TYPE_Array (Z.to_N (Int64.intval k)) TYPE_Double).
  Proof.
    intros * WF LU LU'.
    edestruct WF as (id & LU''); eauto.
    rewrite LU in LU''; inv LU''.
    cbn in *.
    break_match_goal; eauto.
  Qed.

  Lemma WF_IRState_Γ :
    forall (σ : evalContext) (s1 s2 : IRState),
      WF_IRState σ s1 ->
      Γ s1 ≡ Γ s2 ->
      WF_IRState σ s2.
  Proof.
    intros σ s1 s2 WF GAMMA.
    unfold WF_IRState.
    rewrite <- GAMMA.
    apply WF.
  Qed.

End WF_IRState.

Ltac abs_by_WF :=
  match goal with
  | h  : nth_error (Γ ?s) _ ≡ Some (?id,?τ),
         h': @nth_error DSHVal ?σ _ ≡ Some ?val
    |- _ =>
    let WF := fresh "WF" in
    assert (WF : WF_IRState σ s) by eauto;
    let H := fresh in pose proof (WF_IRState_lookups _ WF h h') as H; now (destruct id; inv H)
  | h : nth_error (Γ ?s) _ ≡ Some (?id,?τ) |- _ =>
    match id with
    | ID_Local _ =>
      eapply WF_IRState_one_of_local_type in h; eauto;
      now (let EQ := fresh in destruct h as [EQ | [EQ | [? EQ]]]; inv EQ)
    | ID_Global _ =>
      eapply WF_IRState_one_of_global_type in h; eauto;
      now (let EQ := fresh in destruct h as [EQ | [EQ | [? EQ]]]; inv EQ)
    end
  end.

Ltac abs_failure :=
  exfalso;
  unfold Dfail, Sfail in *;
  match goal with
  | h: no_failure (interp_helix (throw _) _) |- _ =>
    exact (failure_helix_throw _ _ h)
  | h: no_failure (interp_helix (ITree.bind (throw _) _) _) |- _ =>
    exact (failure_helix_throw' _ _ _ h)
  | h: no_failure (interp_helix (ITree.bind (Ret _) _)  _) |- _ =>
    eapply no_failure_Ret in h; abs_failure
  end.
Ltac try_abs :=
  try (abs_by_WF || abs_failure).


(* Ltac try_abs := *)
(*   try (abs_by_WF || *)
(*        abs_by failure_helix_throw || abs_by failure_helix_throw'). *)

Section SimulationRelations.

  (**
     We define in this section the principal simulation relations used:
     - At the top-level to relate full [FSHCOLProgram]s to the full Vellvm
     program resulting from their compilation: see [compiler_correct]
     - At the top-level to relate these same program after initialization of
     the runtime. (TODOYZ: Do we need one such?)
     - When relating operators to the sub-cfg resulting from their compilation:
     see [compile_FSHCOL_correct]

    These relations also get refined when related sub-structures of the operators,
    we define these refinements in the corresponding sections.
   *)

  (**
     Relation used to relate memories after the initialization phase.
     Recall: [Type_R_memory ≜ memoryH -> LLVM_memory_state_cfg -> Prop]
   *)

  (* Conversion from Helix values to VIR values *)
  Definition dvalue_of_int (v : Int64.int) : dvalue := DVALUE_I64 (DynamicValues.Int64.repr (Int64.intval v)).
  Definition dvalue_of_bin (v: binary64)   : dvalue := DVALUE_Double v.

  (* Check that a pair of [ident] and [dvalue] can be found in the
     appropriate environment. This to be used only for scalar values,
     like [int] or [double] *)
  Definition in_local_or_global_scalar
             (ρ : local_env) (g : global_env) (m : memoryV)
             (x : ident) (dv : dvalue) (τ : typ) : Prop
    := match x with
       | ID_Local  x => ρ @ x ≡ Some (dvalue_to_uvalue dv)
       | ID_Global x =>
         exists ptr τ',
         τ ≡ TYPE_Pointer τ' /\
         g @ x ≡ Some (DVALUE_Addr ptr) /\
         read m ptr (typ_to_dtyp [] τ') ≡ inr (dvalue_to_uvalue dv)
       end.

  (* Check that a pair of [ident] and [dvalue] can be found in the
     appropriate environment. *)
  Definition in_local_or_global_addr
             (ρ : local_env) (g : global_env)
             (x : ident) (a : Addr.addr): Prop
    := match x with
       | ID_Local  x => ρ @ x ≡ Some (UVALUE_Addr a)
       | ID_Global x => g @ x ≡ Some (DVALUE_Addr a)
       end.

  Definition no_dshptr_aliasing (σ : evalContext) : Prop :=
    forall n n' ptr sz sz',
      nth_error σ n ≡ Some (DSHPtrVal ptr sz) ->
      nth_error σ n' ≡ Some (DSHPtrVal ptr sz') ->
      n' ≡ n.

  Definition id_allocated (σ : evalContext) (m : memoryH) : Prop :=
    forall n addr val,
      nth_error σ n ≡ Some (DSHPtrVal addr val) ->
      mem_block_exists addr m.

  Definition no_id_aliasing (σ : evalContext) (s : IRState) : Prop :=
    forall n1 n2 id τ τ' v1 v2,
      nth_error σ n1 ≡ Some v1 ->
      nth_error σ n2 ≡ Some v2 ->
      nth_error (Γ s) n1 ≡ Some (id, τ) ->
      nth_error (Γ s) n2 ≡ Some (id, τ') ->
      n2 ≡ n1. 

  Definition no_llvm_ptr_aliasing (σ : evalContext) (s : IRState) (ρ : local_env) (g : global_env) : Prop :=
    forall (id1 : ident) (ptrv1 : addr) (id2 : ident) (ptrv2 : addr) n1 n2 τ τ' v1 v2,
      nth_error σ n1 ≡ Some v1 ->
      nth_error σ n2 ≡ Some v2 ->
      nth_error (Γ s) n1 ≡ Some (id1, τ) ->
      nth_error (Γ s) n2 ≡ Some (id2, τ') ->
      id1 ≢ id2 ->
      in_local_or_global_addr ρ g id1 ptrv1 ->
      in_local_or_global_addr ρ g id2 ptrv2 ->
      fst ptrv1 ≢ fst ptrv2.

  Definition no_llvm_ptr_aliasing_cfg (σ : evalContext) (s : IRState) : config_cfg -> Prop :=
    fun '(mv, (ρ, g)) => no_llvm_ptr_aliasing σ s ρ g.

  (* TODO: might not keep this *)
  Definition dshptr_no_block_aliasing (σ : evalContext) ρ g dshp1 (ptrv1 : addr) : Prop :=
    forall dshp2 n2 sz2 s id2 ptrv2 τ,
      dshp1 ≢ dshp2 ->
      nth_error σ n2 ≡ Some (DSHPtrVal dshp2 sz2) ->
      nth_error (Γ s) n2 ≡ Some (id2, τ) ->
      in_local_or_global_addr ρ g id2 ptrv2 ->
      fst ptrv1 ≢ fst ptrv2.

  Lemma incLocal_no_id_aliasing :
    forall s1 s2 id σ,
      incLocal s1 ≡ inr (s2, id) ->
      no_id_aliasing σ s1 ->
      no_id_aliasing σ s2.
  Proof.
    intros s1 s2 id * INC ALIAS.
    unfold no_id_aliasing in *.
    apply incLocal_Γ in INC.
    rewrite INC.
    auto.
  Qed.

  Lemma no_id_aliasing_n_eq :
    forall s σ n n' id τ τ' v v',
      no_id_aliasing σ s ->
      nth_error σ n ≡ Some v ->
      nth_error σ n' ≡ Some v' ->
      nth_error (Γ s) n ≡ Some (id, τ) ->
      nth_error (Γ s) n' ≡ Some (id, τ') ->
      n' ≡ n.
  Proof.
    intros s σ n n' id τ τ' ALIAS N1 N2.
    edestruct ALIAS; eauto. 
  Qed.

  Definition no_local_global_alias (l : local_env) (g : global_env) (v : uvalue) : Prop :=
    forall id p p', v ≡ UVALUE_Addr p -> in_local_or_global_addr l g id p' -> fst p ≢ fst p'.

  (* TODO: Move this *)
  Lemma in_local_or_global_addr_neq :
    forall l g id id' v ptr,
      in_local_or_global_addr l g (ID_Local id) ptr ->
      id ≢ id' ->
      in_local_or_global_addr (alist_add id' v l) g (ID_Local id) ptr.
  Proof.
    intros l g id id' v ptr H H0.
    unfold in_local_or_global_addr.
    rewrite alist_find_neq; eauto.
  Qed.

  (* Main memory invariant. Relies on Helix's evaluation context and the [IRState] built by the compiler.
     At any indices, the value and ident/types respectively found are related in that:
     - integers and floats have their translation in the appropriate VIR environment;
     - pointers have a corresponding pointer in the appropriate VIR environment such that they map on identical arrays
   *)
  Definition memory_invariant (σ : evalContext) (s : IRState) : Rel_cfg :=
    fun (mem_helix : MDSHCOLOnFloat64.memory) '(mem_llvm, (ρ,g)) =>
      forall (n: nat) v τ x,
        nth_error σ n ≡ Some v ->
        nth_error (Γ s) n ≡ Some (x,τ) ->
        match v with
        | DSHnatVal v   => in_local_or_global_scalar ρ g mem_llvm x (dvalue_of_int v) τ
        | DSHCTypeVal v => in_local_or_global_scalar ρ g mem_llvm x (dvalue_of_bin v) τ
        | DSHPtrVal ptr_helix ptr_size_helix =>
          exists bk_helix ptr_llvm τ',
          memory_lookup mem_helix ptr_helix ≡ Some bk_helix /\
          τ ≡ TYPE_Pointer τ' /\
          dtyp_fits mem_llvm ptr_llvm (typ_to_dtyp [] τ') /\
          in_local_or_global_addr ρ g x ptr_llvm /\
          (forall (i : Int64.int) v, mem_lookup (MInt64asNT.to_nat i) bk_helix ≡ Some v ->
                       get_array_cell mem_llvm ptr_llvm (MInt64asNT.to_nat i) DTYPE_Double ≡ inr (UVALUE_Double v))
        end.

  (* Lookups in [genv] are fully determined by lookups in [Γ] and [σ] *)
  Lemma memory_invariant_GLU : forall σ s v id memH memV t l g n,
      memory_invariant σ s memH (memV, (l, g)) ->
      nth_error (Γ s) v ≡ Some (ID_Global id, TYPE_Pointer t) ->
      nth_error σ v ≡ Some (DSHnatVal n) ->
      exists ptr, Maps.lookup id g ≡ Some (DVALUE_Addr ptr) /\
                  read memV ptr (typ_to_dtyp [] t) ≡ inr (dvalue_to_uvalue (DVALUE_I64 n)).
  Proof.
    intros * MEM_INV NTH LU; cbn* in *.
    eapply MEM_INV in LU; clear MEM_INV; eauto.
    destruct LU as (ptr & τ & EQ & LU & READ); inv EQ.
    exists ptr; split; auto.
    cbn in *.
    rewrite repr_intval in READ; auto.
  Qed.

  (* Lookups in [local_env] are fully determined by lookups in [Γ] and [σ] *)
  Lemma memory_invariant_LLU : forall σ s v id memH memV t l g n,
      memory_invariant σ s memH (memV, (l, g)) ->
      nth_error (Γ s) v ≡ Some (ID_Local id, t) ->
      nth_error σ v ≡ Some (DSHnatVal n) ->
      Maps.lookup id l ≡ Some (UVALUE_I64 n).
  Proof.
    intros * MEM_INV NTH LU; cbn* in *.
    eapply MEM_INV in LU; clear MEM_INV; eauto.
    unfold in_local_or_global_scalar, dvalue_of_int in LU.
    rewrite repr_intval in LU; auto.
  Qed.

  (* Lookups in [local_env] are fully determined by lookups in [vars] and [σ] *)
  Lemma memory_invariant_LLU_AExpr : forall σ s v id memH memV t l g f,
      memory_invariant σ s memH (memV, (l, g)) ->
      nth_error (Γ s) v ≡ Some (ID_Local id, t) ->
      nth_error σ v ≡ Some (DSHCTypeVal f) ->
      Maps.lookup id l ≡ Some (UVALUE_Double f).
  Proof.
    intros * MEM_INV NTH LU; cbn* in *.
    eapply MEM_INV in LU; clear MEM_INV; eauto.
    unfold in_local_or_global_scalar, dvalue_of_int in LU.
    cbn in LU; auto.
  Qed.

  (* Lookups in [genv] are fully determined by lookups in [vars] and [σ] *)
  Lemma memory_invariant_GLU_AExpr : forall σ s v id memH memV t l g f,
      memory_invariant σ s memH (memV, (l, g)) ->
      nth_error (Γ s) v ≡ Some (ID_Global id, TYPE_Pointer t) ->
      nth_error σ v ≡ Some (DSHCTypeVal f) ->
      exists ptr, Maps.lookup id g ≡ Some (DVALUE_Addr ptr) /\
                  read memV ptr (typ_to_dtyp [] t) ≡ inr (dvalue_to_uvalue (DVALUE_Double f)).
  Proof.
    intros * MEM_INV NTH LU; cbn* in *.
    eapply MEM_INV in LU; clear MEM_INV; eauto.
    destruct LU as (ptr & τ & EQ & LU & READ); inv EQ.
    exists ptr; split; auto.
  Qed.

  Lemma memory_invariant_LLU_Ptr : forall σ s v id memH memV t l g m size,
      memory_invariant σ s memH (memV, (l, g)) ->
      nth_error (Γ s) v ≡ Some (ID_Local id, t) ->
      nth_error σ v ≡ Some (DSHPtrVal m size) ->
      exists (bk_h : mem_block) (ptr_v : Addr.addr) t',
        memory_lookup memH m ≡ Some bk_h
        /\ t ≡ TYPE_Pointer t'
        /\ dtyp_fits memV ptr_v (typ_to_dtyp [] t')
        /\ in_local_or_global_addr l g (ID_Local id) ptr_v
        /\ (forall (i : Int64.int) (v : binary64),
               mem_lookup (MInt64asNT.to_nat i) bk_h ≡ Some v -> get_array_cell memV ptr_v (MInt64asNT.to_nat i) DTYPE_Double ≡ inr (UVALUE_Double v)).
  Proof.
    intros * MEM_INV NTH LU; cbn* in *.
    eapply MEM_INV in LU; clear MEM_INV; eauto.
    auto.
  Qed.

  Lemma ptr_alias_size_eq :
    forall σ n1 n2 sz1 sz2 p,
      no_dshptr_aliasing σ ->
      nth_error σ n1 ≡ Some (DSHPtrVal p sz1) ->
      nth_error σ n2 ≡ Some (DSHPtrVal p sz2) ->
      sz1 ≡ sz2.
  Proof.
    intros σ n1 n2 sz1 sz2 p ALIAS N1 N2.
    pose proof (ALIAS _ _ _ _ _ N1 N2); subst.
    rewrite N1 in N2; inversion N2.
    auto.
  Qed.

  (** ** General state invariant
      The main invariant carried around combine the two properties defined:
      1. the memories satisfy the invariant;
      2. the [IRState] is well formed;
      3. 
   *)
  Record state_invariant (σ : evalContext) (s : IRState) (memH : memoryH) (configV : config_cfg) : Prop :=
    {
    mem_is_inv : memory_invariant σ s memH configV ;
    IRState_is_WF : WF_IRState σ s ;
    st_no_id_aliasing : no_id_aliasing σ s ;
    st_no_dshptr_aliasing : no_dshptr_aliasing σ ;
    st_no_llvm_ptr_aliasing : no_llvm_ptr_aliasing_cfg σ s configV ;
    st_id_allocated : id_allocated σ memH
    }.

  (* Predicate stating that an (llvm) local variable is relevant to the memory invariant *)
  Variant in_Gamma : evalContext -> IRState -> raw_id -> Prop :=
  | mk_in_Gamma : forall σ s id τ n v,
      nth_error σ n ≡ Some v ->
      nth_error (Γ s) n ≡ Some (ID_Local id,τ) ->
      WF_IRState σ s ->
      in_Gamma σ s id.

  (* Given a range defined by [s1;s2], ensures that the whole range is irrelevant to the memory invariant *)
  Definition Gamma_safe σ (s1 s2 : IRState) : Prop :=
    forall id, lid_bound_between s1 s2 id ->
               ~ in_Gamma σ s1 id.

  (* Given an initial local env [l1] that reduced to [l2], ensures that no variable relevant to the memory invariant has been modified *)
  Definition Gamma_preserved σ s (l1 l2 : local_env) : Prop :=
    forall id, in_Gamma σ s id ->
               l1 @ id ≡ l2 @ id.

  (* Given an initial local env [l1] that reduced to [l2], and a range given by [s1;s2], ensures
   that all modified variables came from this range *)
  Definition local_scope_modif (s1 s2 : IRState) (l1 : local_env) : local_env -> Prop :=
    fun l2 =>
      forall id,
        alist_find id l2 <> alist_find id l1 ->
        lid_bound_between s1 s2 id.

  (* Given an initial local env [l1] that reduced to [l2], and a range given by [s1;s2], ensures
   that this range has been left untouched *)
  Definition local_scope_preserved (s1 s2 : IRState) (l1 : local_env) : local_env -> Prop :=
    fun l2 => forall id,
        lid_bound_between s1 s2 id ->
        l2 @ id ≡ l1 @ id.

  (* Expresses that only the llvm local env has been modified *)
  Definition almost_pure {R S} : config_helix -> config_cfg -> Rel_cfg_T R S :=
    fun mh '(mi,(li,gi)) '(mh',_) '(m,(l,(g,_))) =>
      mh ≡ mh' /\ mi ≡ m /\ gi ≡ g.

  Definition is_pure {R S}: memoryH -> config_cfg -> Rel_cfg_T R S :=
    fun mh '(mi,(li,gi)) '(mh',_) '(m,(l,(g,_))) => mh ≡ mh' /\ mi ≡ m /\ gi ≡ g /\ li ≡ l.

  Lemma is_pure_refl:
    forall {R S} memH memV l g n v,
      @is_pure R S memH (mk_config_cfg memV l g) (memH, n) (memV, (l, (g, v))).
  Proof.
    intros; repeat split; reflexivity.
  Qed.

  Lemma no_llvm_ptr_aliasing_not_in_gamma :
    forall σ s id v l g,
      no_llvm_ptr_aliasing σ s l g ->
      WF_IRState σ s ->
      ~ in_Gamma σ s id ->
      no_llvm_ptr_aliasing σ s (alist_add id v l) g.
  Proof.
    intros σ s id v l g ALIAS WF FRESH.
    unfold no_llvm_ptr_aliasing in *.
    intros id1 ptrv1 id2 ptrv2 n1 n2 τ0 τ' v1 v2 H H0 H1 H2 H3 H4 H5.
    destruct id1, id2.
    - epose proof (ALIAS _ _ _ _ _ _ _ _ _ _ H H0 H1 H2 H3 H4 H5).
      eauto.
    - epose proof (ALIAS _ _ _ ptrv2 _ _ _ _ _ _ H H0 H1 H2 H3 H4).
      destruct (rel_dec_p id1 id) as [EQ | NEQ]; unfold Eqv.eqv, eqv_raw_id in *.
      + subst.
        assert (in_Gamma σ s id).
        econstructor; eauto.
        exfalso; apply FRESH; auto.
      + eapply H6.
        cbn in *.
        pose proof NEQ.
        rewrite alist_find_neq in H5; auto.
    - epose proof (ALIAS _ ptrv1 _ ptrv2 _ _ _ _ _ _ H H0 H1 H2 H3).
      destruct (rel_dec_p id0 id).
      + subst.
        assert (in_Gamma σ s id).
        { econstructor.
          2: eapply H1.
          all:eauto.
        }
        exfalso; apply FRESH; auto.
      + cbn in *.
        apply In_add_ineq_iff in H4; eauto.
    - unfold alist_fresh in *.
      destruct (rel_dec_p id0 id).
      + subst.
        destruct (rel_dec_p id1 id).
        * subst.
          contradiction.
        * epose proof (ALIAS _ ptrv1 _ ptrv2 _ _ _ _ _ _ H H0 H1 H2 H3).
          assert (in_Gamma σ s id).
          { econstructor.
            2: eapply H1.
            all:eauto.
          }
          exfalso; apply FRESH; auto.
      + destruct (rel_dec_p id1 id).
        * subst.
          epose proof (ALIAS _ ptrv1 _ ptrv2 _ _ _ _ _ _ H H0 H1 H2 H3).
          assert (in_Gamma σ s id).
          econstructor; eauto.
          exfalso; apply FRESH; auto.
        * cbn in *.
          apply In_add_ineq_iff in H4; eauto.
          apply In_add_ineq_iff in H5; eauto.
  Qed.

  (* The memory invariant is stable by evolution of IRStates that preserve Γ *)
  Lemma state_invariant_same_Γ :
    ∀ (σ : evalContext) (s1 s2 : IRState) (id : raw_id) (memH : memoryH) (memV : memoryV) 
      (l : local_env) (g : global_env) (v : uvalue),
      Γ s1 ≡ Γ s2 ->
      ~ in_Gamma σ s1 id →
      state_invariant σ s1 memH (memV, (l, g)) →
      state_invariant σ s2 memH (memV, (alist_add id v l, g)).
  Proof.
    intros * EQ NIN INV; inv INV.
    assert (WF_IRState σ s2) as WF.
    { red; rewrite <- EQ; auto. }
    constructor; auto.
    - cbn; rewrite <- EQ.
      intros * LUH LUV.
      generalize LUV; intros INLG;
        eapply mem_is_inv0 in INLG; eauto.
      destruct v0; cbn in *; auto.
      + destruct x; cbn in *; auto.
        unfold alist_add; cbn.
        break_match_goal.
        * rewrite rel_dec_correct in Heqb; subst.
          exfalso; eapply NIN.
          econstructor; eauto.
        * apply neg_rel_dec_correct in Heqb.
          rewrite remove_neq_alist; eauto.
          all: typeclasses eauto.
      + destruct x; cbn; auto.
        unfold alist_add; cbn.
        break_match_goal.
        * rewrite rel_dec_correct in Heqb; subst.
          exfalso; eapply NIN.
          econstructor; eauto.
        * apply neg_rel_dec_correct in Heqb.
          rewrite remove_neq_alist; eauto.
          all: typeclasses eauto.
      + destruct x; cbn in *; auto.
        destruct INLG as (? & ? & ? & ? & ? & ? & ? & ?).
        do 3 eexists; split; [eauto | split]; eauto.
        unfold alist_add; cbn.
        break_match_goal.
        * rewrite rel_dec_correct in Heqb; subst.
          exfalso; eapply NIN.
          econstructor; eauto.
        * apply neg_rel_dec_correct in Heqb.
          rewrite remove_neq_alist; eauto.
          all: typeclasses eauto.
    - red; rewrite <- EQ; auto.
    - apply no_llvm_ptr_aliasing_not_in_gamma; eauto.
      red; rewrite <- EQ; auto.

      intros INGAMMA.
      destruct INGAMMA.
      apply NIN.
      rewrite <- EQ in H0.
      econstructor; eauto.
  Qed.

  Lemma state_invariant_memory_invariant :
    forall σ s mH mV l g,
      state_invariant σ s mH (mV,(l,g)) ->
      memory_invariant σ s mH (mV,(l,g)).
  Proof.
    intros * H; inv H; auto.
  Qed.

  (* The memory invariant is stable by extension of the local environment
   if the variable belongs to a Γ safe interval
   *)
  Lemma state_invariant_add_fresh :
    ∀ (σ : evalContext) (s1 s2 : IRState) (id : raw_id) (memH : memoryH) (memV : memoryV) 
      (l : local_env) (g : global_env) (v : uvalue),
      incLocal s1 ≡ inr (s2, id)
      -> WF_IRState σ s2
      -> Gamma_safe σ s1 s2
      → state_invariant σ s1 memH (memV, (l, g))
      → state_invariant σ s2 memH (memV, (alist_add id v l, g)).
  Proof.
    intros * INC SAFE INV.
    eapply state_invariant_same_Γ; eauto using lid_bound_between_incLocal.
    symmetry; eapply incLocal_Γ; eauto.
  Qed.

  Lemma incVoid_no_id_aliasing :
    forall s1 s2 id σ,
      incVoid s1 ≡ inr (s2, id) ->
      no_id_aliasing σ s1 ->
      no_id_aliasing σ s2.
  Proof.
    intros s1 s2 id SIG INC ALIAS.
    unfold no_id_aliasing in *.
    apply incVoid_Γ in INC.
    rewrite INC.
    auto.
  Qed.

  Lemma incVoid_no_llvm_ptr_aliasing :
    forall σ s1 s2 id l g,
      incVoid s1 ≡ inr (s2, id) ->
      no_llvm_ptr_aliasing σ s1 l g ->
      no_llvm_ptr_aliasing σ s2 l g.
  Proof.
    intros σ s1 s2 id l g INC ALIAS.
    unfold no_llvm_ptr_aliasing in *.
    apply incVoid_Γ in INC.
    rewrite INC.
    auto.
  Qed.

  Lemma state_invariant_incVoid :
    forall σ s s' k memH stV,
      incVoid s ≡ inr (s', k) ->
      state_invariant σ s memH stV ->
      state_invariant σ s' memH stV.
  Proof.
    intros * INC INV; inv INV.
    split; eauto.
    - red; repeat break_let; intros * LUH LUV.
      assert (Γ s' ≡ Γ s) as GAMMA by (eapply incVoid_Γ; eauto).
      rewrite GAMMA in *.
      generalize LUV; intros INLG;
        eapply mem_is_inv0 in INLG; eauto. 
    - unfold WF_IRState; erewrite incVoid_Γ; eauto; apply WF.
    - eapply incVoid_no_id_aliasing; eauto.
    - destruct stV as [m [l g]].
      eapply incVoid_no_llvm_ptr_aliasing; eauto.
  Qed.

  (* If no change has been made, all changes are certainly in the interval *)
  Lemma local_scope_modif_refl: forall s1 s2 l, local_scope_modif s1 s2 l l.
  Proof.
    intros; red; intros * NEQ.
    contradiction NEQ; auto.
  Qed.

  (* If a single change has been made, we just need to check that it was in the interval *)
  Lemma local_scope_modif_add: forall s1 s2 l r v,
      lid_bound_between s1 s2 r ->   
      local_scope_modif s1 s2 l (alist_add r v l).
  Proof.
    intros * BET.
    red; intros * NEQ.
    destruct (rel_dec_p r id).
    - subst; rewrite alist_find_add_eq in NEQ; auto.
    - rewrite alist_find_neq in NEQ; auto.
      contradiction NEQ; auto.
  Qed.

  (* Gives a way to work with multiple changes made to locals *)
  Lemma local_scope_modif_add': forall s1 s2 l l' r v,
      lid_bound_between s1 s2 r ->
      local_scope_modif s1 s2 l l' ->
      local_scope_modif s1 s2 l (alist_add r v l').
  Proof.
    intros * BET MODIF.
    red; intros * NEQ.
    destruct (rel_dec_p r id).
    - subst; rewrite alist_find_add_eq in NEQ; auto.
    - rewrite alist_find_neq in NEQ; auto.
  Qed.

  (* If all changes made are in the empty interval, then no change has been made *)
  Lemma local_scope_modif_empty_scope:
    forall (l1 l2 : local_env) id s,
      local_scope_modif s s l1 l2 ->
      l2 @ id ≡ l1 @ id.
  Proof.
    intros * SCOPE.
    red in SCOPE.
    edestruct @alist_find_eq_dec_local_env as [EQ | NEQ]; [eassumption|].
    exfalso; apply SCOPE in NEQ; clear SCOPE.
    destruct NEQ as (? & ? & ? & ? & ? & ? & ?).
    cbn in *; inv H2.
    lia.
  Qed.

  (* If I know that all changes came from [s2;s3] and that I consider a variable from another interval, then it hasn't changed *)
  Lemma local_scope_modif_out:
    forall (l1 l2 : local_env) id s1 s2 s3,
      s1 << s2 ->
      lid_bound_between s1 s2 id ->
      local_scope_modif s2 s3 l1 l2 ->
      l2 @ id ≡ l1 @ id.
  Proof.
    intros * LT BOUND SCOPE.
    red in SCOPE.
    edestruct @alist_find_eq_dec_local_env as [EQ | NEQ]; [eassumption |].
    exfalso; apply SCOPE in NEQ; clear SCOPE.
    destruct NEQ as (? & ? & ? & ? & ? & ? & ?).
    destruct BOUND as (? & ? & ? & ? & ? & ? & ?).
    cbn in *.
    inv H2; inv H6.
    exfalso; eapply IdLemmas.valid_prefix_neq_differ; [| | | eassumption]; auto.
    lia.
  Qed.

  Lemma local_scope_modif_external :
    forall l1 l2 id s1 s2,
      local_scope_modif s1 s2 l1 l2 ->
      ~ lid_bound_between s1 s2 id ->
      l1 @ id ≡ l2 @ id.
  Proof.
    intros l1 l2 id s1 s2 MODIF NBOUND.
    edestruct @alist_find_eq_dec_local_env as [EQ | NEQ]; [eassumption |].
    exfalso; apply NBOUND; apply MODIF; eauto.
  Qed.

  (* If no change occurred, it left any interval untouched *)
  Lemma local_scope_preserved_refl : forall s1 s2 l,
      local_scope_preserved s1 s2 l l.
  Proof.
    intros; red; intros; reflexivity.
  Qed.

  (* If no change occurred, it left Gamma safe *)
  Lemma Gamma_preserved_refl : forall s1 s2 l,
      Gamma_preserved s1 s2 l l.
  Proof.
    intros; red; intros; reflexivity.
  Qed.

  (* TODO: move this? *)
  Lemma maps_add_neq :
    forall {K} {V} {eqk : K -> K -> Prop} {RD : RelDec eqk} `{RelDec_Correct _ eqk} `{Symmetric _ eqk} `{Transitive _ eqk} (x id : K) (v : V) m,
      ~ eqk id x ->
      Maps.add x v m @ id ≡ m @ id.
  Proof.
    intros K V eqk RD RDC SYM TRANS H x id v m H0.
    cbn. unfold alist_add; cbn. 
    rewrite rel_dec_neq_false; eauto.
    eapply remove_neq_alist; eauto.
  Qed.

  Lemma Gamma_preserved_add_not_in_Gamma:
    forall σ s l l' r v,
      Gamma_preserved σ s l l' ->
      ~ in_Gamma σ s r ->
      Gamma_preserved σ s l (Maps.add r v l').
  Proof.
    intros σ s l l' r v PRES NGAM.
    unfold Gamma_preserved in *.
    intros id H.
    assert (id ≢ r) by (intros CONTRA; subst; contradiction).
    setoid_rewrite maps_add_neq; eauto.
  Qed.

  (* If I know that an interval leaves Gamma safe, I can shrink it on either side and it still lives Gamma safe *)
  Lemma Gamma_safe_shrink : forall σ s1 s2 s3 s4,
      Gamma_safe σ s1 s4 ->
      Γ s1 ≡ Γ s2 ->
      s1 <<= s2 ->
      s3 <<= s4 ->
      Gamma_safe σ s2 s3.
  Proof.
    unfold Gamma_safe; intros * SAFE EQ LE1 LE2 * (? & s & s' & ? & ? & ? & ?) IN.
    apply SAFE with id.
    exists x, s, s'.
    repeat split; eauto.
    solve_local_count.
    solve_local_count.
    inv IN.
    econstructor.
    eauto.
    rewrite EQ; eauto.
    eapply WF_IRState_Γ; eauto.
  Qed.

  Lemma Gamma_safe_Context_extend :
    forall σ s1 s2,
      Gamma_safe σ s1 s2 ->
      forall s1' s2' x v xτ,
        (local_count s1 <= local_count s1')%nat ->
        (local_count s2 >= local_count s2')%nat ->
        Γ s1' ≡ (ID_Local x, v) :: Γ s1 ->
        Γ s2' ≡ (ID_Local x, v) :: Γ s2 ->
        (∀ id : local_id, lid_bound_between s1' s2' id → x ≢ id) ->
        Gamma_safe (xτ :: σ) s1' s2'.
  Proof.
    intros. do 2 red. intros.
    unfold Gamma_safe in H. red in H.
    inversion H3; subst.
    unfold lid_bound_between, state_bound_between in *.
    eapply H.
    - destruct H5 as (? & ? & ? & ? & ? & ? & ?).
      cbn* in *. inversion e; subst. clear e.
      exists x0, x1. eexists. split; auto.
      split. clear H.
      lia. split; auto. lia.
    - inversion H6; subst.
      econstructor.
      3 : {
        unfold WF_IRState in *.
        clear -H10 H2 H4.

        eapply evalContext_typechecks_extend; eauto.
      }

      rewrite H2 in H9.
      destruct n eqn: n' .
      + cbn in *. inversion H9. subst. specialize (H4 id H5).
        contradiction.
      + cbn in *. Unshelve.
        3 : exact (n - 1)%nat. cbn.
        rewrite Nat.sub_0_r. apply H7. eauto.
      + rewrite H2 in H9. cbn in *. inversion H9. subst.
        destruct n. cbn in *.
        specialize (H4 id H5). inversion H9. subst. contradiction.
        cbn. rewrite Nat.sub_0_r. cbn in *. auto.
  Qed.

  (* If I have modified an interval, other intervals are preserved *)
  Lemma local_scope_preserve_modif:
    forall s1 s2 s3 l1 l2,
      s2 << s3 ->
      local_scope_modif s2 s3 l1 l2 ->
      local_scope_preserved s1 s2 l1 l2. 
  Proof.
    intros * LE MOD.
    red. intros * BOUND.
    red in MOD.
    edestruct @alist_find_eq_dec_local_env as [EQ | NEQ]; [eassumption |].
    apply MOD in NEQ; clear MOD.
    destruct NEQ as (msg & s & s' & ? & ? & ? & ?).
    cbn in *; inv H2.
    destruct BOUND as (msg' & s' & s'' & ? & ? & ? & ?).
    cbn in *; inv H5.
    destruct s as [a s b]; cbn in *; clear a b.
    destruct s' as [a s' b]; cbn in *; clear a b.
    destruct s1 as [a s1 b]; cbn in *; clear a b.
    destruct s2 as [a s2 b], s3 as [a' s3 b']; cbn in *.
    red in LE; cbn in *.
    clear a b a' b'.
    exfalso; eapply IdLemmas.valid_prefix_neq_differ; [| | | eassumption]; auto.
    lia.
  Qed.

  Lemma in_Gamma_Gamma_eq:
    forall σ s1 s2 id,
      Γ s1 ≡ Γ s2 ->
      in_Gamma σ s1 id ->
      in_Gamma σ s2 id.
  Proof.
    intros * EQ IN; inv IN; econstructor; eauto.
    rewrite <- EQ; eauto.
    eapply WF_IRState_Γ; eauto.
  Qed.

  Lemma not_in_Gamma_Gamma_eq:
    forall σ s1 s2 id,
      Γ s1 ≡ Γ s2 ->
      ~ in_Gamma σ s1 id ->
      ~ in_Gamma σ s2 id.
  Proof.
    intros σ s1 s2 id EQ NGAM.
    intros GAM.
    apply NGAM.
    inversion GAM; subst.
    econstructor; eauto.
    rewrite EQ. eauto.
    eapply WF_IRState_Γ; eauto.
  Qed.

  Lemma Gamma_preserved_Gamma_eq:
    forall σ s1 s2 l1 l2,
      Γ s1 ≡ Γ s2 ->
      Gamma_preserved σ s1 l1 l2 ->
      Gamma_preserved σ s2 l1 l2.
  Proof.
    unfold Gamma_preserved. intros * EQ PRE * IN.
    apply PRE.
    eauto using in_Gamma_Gamma_eq.
  Qed.

  (* If an interval is Gamma safe, and that all changes occurred in this interval, then the changes preserved Gamma. *)
  Lemma Gamma_preserved_if_safe :
    forall σ s1 s2 l1 l2,
      Gamma_safe σ s1 s2 ->
      local_scope_modif s1 s2 l1 l2 ->
      Gamma_preserved σ s1 l1 l2.
  Proof.
    intros * GS L.
    red.
    intros ? IN.
    red in GS.
    red in L.
    edestruct @alist_find_eq_dec_local_env as [EQ | NEQ]; [eassumption |].
    exfalso; eapply GS; eauto.
  Qed.

  (* Belonging to an interval can relaxed down *)
  Lemma lid_bound_between_shrink_down :
    forall s1 s2 s3 id,
      s1 <<= s2 ->
      lid_bound_between s2 s3 id ->
      lid_bound_between s1 s3 id.
  Proof.
    intros * LE (? & ? & ? & ? & ? & ? & ?).
    do 3 eexists.
    repeat split; eauto.
    solve_local_count.
  Qed.

  (* Belonging to an interval can relaxed up *)
  Lemma lid_bound_between_shrink_up :
    forall s1 s2 s3 id,
      s2 <<= s3 ->
      lid_bound_between s1 s2 id ->
      lid_bound_between s1 s3 id.
  Proof.
    intros * EQ (? & s & s' & ? & ? & ? & ?).
    do 3 eexists.
    repeat split; eauto.
    solve_local_count.
  Qed.

  Lemma lid_bound_between_shrink :
    ∀ (s1 s2 s3 s4 : IRState) (id : local_id),
      lid_bound_between s2 s3 id →
      s1 <<= s2 →
      s3 <<= s4 ->
      lid_bound_between s1 s4 id.
  Proof.
    intros s1 s2 s3 s4 id H H0 H1.
    eapply lid_bound_between_shrink_down; [|eapply lid_bound_between_shrink_up];
      eauto.
  Qed.

  (* Transitivity of the changes belonging to intervals *)
  Lemma local_scope_modif_trans :
    forall s1 s2 s3 l1 l2 l3,
      s1 <<= s2 ->
      s2 <<= s3 ->
      local_scope_modif s1 s2 l1 l2 ->
      local_scope_modif s2 s3 l2 l3 ->
      local_scope_modif s1 s3 l1 l3.
  Proof.
    unfold local_scope_modif; intros * LE1 LE2 MOD1 MOD2 * INEQ.
    destruct (alist_find_eq_dec_local_env id l1 l2) as [EQ | NEQ].
    - destruct (alist_find_eq_dec_local_env id l2 l3) as [EQ' | NEQ'].
      + contradiction INEQ; rewrite <- EQ; auto.
      + apply MOD2 in NEQ'.
        eauto using lid_bound_between_shrink_down.
    - apply MOD1 in NEQ.
      eauto using lid_bound_between_shrink_up.
  Qed.

  (* Alternate notion of transitivity, with respect to a fix interval *)
  Lemma local_scope_modif_trans' :
    forall s1 s2 l1 l2 l3,
      local_scope_modif s1 s2 l1 l2 ->
      local_scope_modif s1 s2 l2 l3 ->
      local_scope_modif s1 s2 l1 l3.
  Proof.
    unfold local_scope_modif; intros * MOD1 MOD2 * INEQ.
    destruct (alist_find_eq_dec_local_env id l1 l2) as [EQ | NEQ].
    - destruct (alist_find_eq_dec_local_env id l2 l3) as [EQ' | NEQ'].
      + contradiction INEQ; rewrite <- EQ; auto.
      + apply MOD2 in NEQ'.
        eauto using lid_bound_between_shrink_down.
    - apply MOD1 in NEQ.
      eauto using lid_bound_between_shrink_up.
  Qed.

  Lemma local_scope_modif_shrink :
    forall (s1 s2 s3 s4 : IRState) l1 l2,
      local_scope_modif s2 s3 l1 l2 ->
      s1 <<= s2 ->
      s3 <<= s4 ->
      local_scope_modif s1 s4 l1 l2.
  Proof.
    intros s1 s2 s3 s4 l1 l2 MODIF LT1 LT2.
    unfold local_scope_modif in *.
    intros id NEQ.
    eapply lid_bound_between_shrink; eauto.
  Qed.

  Lemma memory_invariant_Ptr : forall vid σ s memH memV l g a size x sz,
      state_invariant σ s memH (memV, (l, g)) ->
      nth_error σ vid ≡ Some (DSHPtrVal a size) ->
      nth_error (Γ s) vid ≡ Some (x, TYPE_Pointer (TYPE_Array sz TYPE_Double)) ->
      ∃ (bk_helix : mem_block) (ptr_llvm : Addr.addr),
        memory_lookup memH a ≡ Some bk_helix
        ∧ dtyp_fits memV ptr_llvm
                    (typ_to_dtyp [] (TYPE_Array sz TYPE_Double))
        ∧ in_local_or_global_addr l g x ptr_llvm
        ∧ (∀ (i : Int64.int) (v : binary64), mem_lookup (MInt64asNT.to_nat i) bk_helix ≡ Some v → get_array_cell memV ptr_llvm (MInt64asNT.to_nat i) DTYPE_Double ≡ inr (UVALUE_Double v)).
  Proof.
    intros * MEM LU1 LU2; inv MEM; eapply mem_is_inv0 in LU1; eapply LU1 in LU2; eauto.
    destruct LU2 as (bk & ptr & τ' & ? & ? & ? & ? & ?).
    exists bk. exists ptr.
    inv H0.
    repeat split; eauto.  
  Qed.


  (* Named function pointer exists in global environemnts *)
  Definition global_named_ptr_exists (fnname:string) : Pred_cfg :=
    fun '(mem_llvm, (ρ,g)) => exists mf, g @ (Name fnname) ≡ Some (DVALUE_Addr mf).

  (* For compiled FHCOL programs we need to ensure we have 2 declarations:
     1. "main" function
     2. function, implementing compiled expression.
   *)
  Definition declarations_invariant (fnname:string) : Pred_cfg :=
    fun c =>
      global_named_ptr_exists "main" c /\
      global_named_ptr_exists fnname c.

  (** An invariant which must hold after initialization stage *)
  Record post_init_invariant (fnname:string) (σ : evalContext) (s : IRState) (memH : memoryH) (configV : config_cfg) : Prop :=
    {
    state_inv: state_invariant σ s memH configV;
    decl_inv:  declarations_invariant fnname configV
    }.

  (**
   Lifting of [memory_invariant] to include return values in the relation.
   This relation is used to prove the correctness of the compilation of operators.
   The value on the Helix side is trivially [unit]. The value on the Vellvm-side however
   is non trivial, we will most likely have to mention it.
   *)
  (* TODO: Currently this relation just preserves memory invariant.
   Maybe it needs to do something more?
   *)
  Definition bisim_partial (σ : evalContext) (s : IRState) : Type_R_partial
    :=
      fun '(mem_helix, _) '(mem_llvm, x) =>
        let '(ρ, (g, _)) := x in
        memory_invariant σ s mem_helix (mem_llvm, (ρ, g)).

  (**
   Relation over memory and invariant for a full [cfg], i.e. to relate states at
   the top-level. lift_R_memory_mcfg
   Currently a simple lifting of [bisim_partial].
   *)
  Definition bisim_full (σ : evalContext) (s : IRState) : Type_R_full  :=
    fun '(mem_helix, _) mem_llvm =>
      let '(m, ((ρ,_), (g, v))) := mem_llvm in
      bisim_partial σ s (mem_helix, tt) (mk_config_cfg_T (inr v) (m, (ρ, g))).

  (** Relation bewteen the final states of evaluation and execution
    of DHCOL program.

    At this stage we do not care about memory or environemnts, and
    just compare return value of [main] function in LLVM with
    evaulation results of DSHCOL.
   *)
  Definition bisim_final (σ : evalContext) : Type_R_full :=
    fun '(_, h_result) '(_,(_,(_,llvm_result))) =>
      match llvm_result with
      | UVALUE_Array arr => @List.Forall2 _ _
                                          (fun ve de =>
                                             match de with
                                             | UVALUE_Double d =>
                                               Floats.Float.cmp Integers.Ceq d ve
                                             | _ => False
                                             end)
                                          h_result arr
      | _ => False
      end.

End SimulationRelations.

Lemma state_invariant_WF_IRState :
  forall σ s memH st, state_invariant σ s memH st -> WF_IRState σ s.
Proof.
  intros ? ? ? (? & ? & ?) INV; inv INV; auto.
Qed.

Lemma in_local_or_global_scalar_same_global : forall l g l' m id dv τ,
    in_local_or_global_scalar l g m (ID_Global id) dv τ ->
    in_local_or_global_scalar l' g m (ID_Global id) dv τ.
Proof.
  cbn; intros; auto.
Qed.

Lemma in_local_or_global_addr_same_global : forall l g l' id ptr,
    in_local_or_global_addr l g (ID_Global id) ptr ->
    in_local_or_global_addr l' g (ID_Global id) ptr.
Proof.
  cbn; intros; auto.
Qed.

Lemma in_local_or_global_scalar_add_fresh_old :
  forall (id : raw_id) (l : local_env) (g : global_env) m (x : ident) dv dv' τ,
    x <> ID_Local id ->
    in_local_or_global_scalar l g m x dv τ ->
    in_local_or_global_scalar (alist_add id dv' l) g m x dv τ.
Proof.
  intros * INEQ LUV'.
  destruct x; cbn in *; auto.
  unfold alist_add; cbn.
  rewrite rel_dec_neq_false; try typeclasses eauto; [| intros ->; auto].
  rewrite remove_neq_alist; auto; try typeclasses eauto; intros ->; auto.
Qed.

Lemma in_local_or_global_addr_add_fresh_old :
  forall (id : raw_id) (l : local_env) (g : global_env) (x : ident) ptr dv',
    x <> ID_Local id ->
    in_local_or_global_addr l g x ptr ->
    in_local_or_global_addr (alist_add id dv' l) g x ptr.
Proof.
  intros * INEQ LUV'.
  destruct x; cbn in *; auto.
  unfold alist_add; cbn.
  rewrite rel_dec_neq_false; try typeclasses eauto; [| intros ->; auto].
  rewrite remove_neq_alist; auto; try typeclasses eauto; intros ->; auto.
Qed.

Lemma append_factor_left : forall s s1 s2,
    s @@ s1 ≡ s @@ s2 ->
    s1 ≡ s2.
Proof.
  induction s as [| c s IH]; cbn; intros * EQ; auto.
  apply IH.
  inv EQ; auto.
Qed.

Lemma state_invariant_incLocal :
  forall σ s s' k memH stV,
    incLocal s ≡ inr (s', k) ->
    state_invariant σ s memH stV ->
    state_invariant σ s' memH stV.
Proof.
  intros * INC [MEM_INV WF].
  split; eauto.
  - red; repeat break_let; intros * LUH LUV.
    pose proof INC as INC'.
    apply incLocal_Γ in INC; rewrite INC in *.
    generalize LUV; intros INLG;
      eapply MEM_INV in INLG; eauto.
  - unfold WF_IRState; erewrite incLocal_Γ; eauto; apply WF.
  - eapply incLocal_no_id_aliasing; eauto.
  - apply incLocal_Γ in INC.
    unfold no_llvm_ptr_aliasing_cfg, no_llvm_ptr_aliasing in *.
    destruct stV as [mv [l g]].
    rewrite INC in *.
    eauto.
Qed.

Lemma incLocalNamed_no_id_aliasing :
  forall s1 s2 msg id σ,
    incLocalNamed msg s1 ≡ inr (s2, id) ->
    no_id_aliasing σ s1 ->
    no_id_aliasing σ s2.
Proof.
  intros s1 s2 msg id * INC ALIAS.
  unfold no_id_aliasing in *.
  apply incLocalNamed_Γ in INC.
  rewrite INC.
  auto.
Qed.

Lemma state_invariant_incLocalNamed :
  forall σ msg s s' k memH stV,
    incLocalNamed msg s ≡ inr (s', k) ->
    state_invariant σ s memH stV ->
    state_invariant σ s' memH stV.
Proof.
  intros * INC [MEM_INV WF].
  split; eauto.
  - red; repeat break_let; intros * LUH LUV.
    pose proof INC as INC'.
    apply incLocalNamed_Γ in INC; rewrite INC in *.
    generalize LUV; intros INLG;
      eapply MEM_INV in INLG; eauto.
  - unfold WF_IRState; erewrite incLocalNamed_Γ; eauto; apply WF.
  - eapply incLocalNamed_no_id_aliasing; eauto.
  - apply incLocalNamed_Γ in INC.
    unfold no_llvm_ptr_aliasing_cfg, no_llvm_ptr_aliasing in *.
    destruct stV as [mv [l g]].
    rewrite INC in *.
    eauto.
Qed.

Lemma incBlockNamed_no_id_aliasing :
  forall s1 s2 msg id σ,
    incBlockNamed msg s1 ≡ inr (s2, id) ->
    no_id_aliasing σ s1 ->
    no_id_aliasing σ s2.
Proof.
  intros s1 s2 msg id * INC ALIAS.
  unfold no_id_aliasing in *.
  apply incBlockNamed_Γ in INC.
  rewrite INC.
  auto.
Qed.

Lemma state_invariant_incBlockNamed :
  forall σ s s' k msg memH stV,
    incBlockNamed msg s ≡ inr (s', k) ->
    state_invariant σ s memH stV ->
    state_invariant σ s' memH stV.
Proof.
  intros * INC [MEM_INV WF].
  split; eauto.
  - red; repeat break_let; intros * LUH LUV.
    pose proof INC as INC'.
    apply incBlockNamed_Γ in INC; rewrite INC in *.
    generalize LUV; intros INLG;
      eapply MEM_INV in INLG; eauto.
  - unfold WF_IRState; erewrite incBlockNamed_Γ; eauto; apply WF.
  - eapply incBlockNamed_no_id_aliasing; eauto.
  - apply incBlockNamed_Γ in INC.
    unfold no_llvm_ptr_aliasing_cfg, no_llvm_ptr_aliasing in *.
    destruct stV as [mv [l g]].
    rewrite INC in *.
    eauto.
Qed.

Lemma state_invariant_no_llvm_ptr_aliasing :
  forall σ s mh mv l g,
    state_invariant σ s mh (mv, (l, g)) ->
    no_llvm_ptr_aliasing σ s l g.
Proof.
  intros σ s mh mv l g SINV.
  destruct SINV. cbn in *.
  auto.
Qed.

Lemma no_id_aliasing_gamma :
  forall s1 s2 σ,
    no_id_aliasing σ s1 ->
    Γ s1 ≡ Γ s2 ->
    no_id_aliasing σ s2.
Proof.
  intros s1 s2 σ ALIAS GAMMA.
  unfold no_id_aliasing.
  rewrite <- GAMMA.
  auto.
Qed.

Lemma no_llvm_ptr_aliasing_gamma :
  forall σ s1 s2 l g,
    no_llvm_ptr_aliasing σ s1 l g ->
    Γ s1 ≡ Γ s2 ->
    no_llvm_ptr_aliasing σ s2 l g.
Proof.
  intros σ s1 s2 l g ALIAS GAMMA.
  unfold no_llvm_ptr_aliasing.
  rewrite <- GAMMA.
  auto.
Qed.

Lemma state_invariant_Γ :
  forall σ s1 s2 memH stV,
    state_invariant σ s1 memH stV ->
    Γ s2 ≡ Γ s1 ->
    state_invariant σ s2 memH stV.
Proof.
  intros * INV EQ; inv INV.
  split; cbn; eauto.
  - red; rewrite EQ; apply mem_is_inv0.
  - red. rewrite EQ; apply IRState_is_WF0.
  - eapply no_id_aliasing_gamma; eauto.
  - destruct stV as (? & ? & ?); cbn in *; eapply no_llvm_ptr_aliasing_gamma; eauto.
Qed.

Lemma state_invariant_add_fresh' :
  ∀ (σ : evalContext) (s1 s2 : IRState) (id : raw_id) (memH : memoryH) (memV : memoryV) 
    (l : local_env) (g : global_env) (v : uvalue),
    Gamma_safe σ s1 s2
    -> lid_bound_between s1 s2 id
    → state_invariant σ s1 memH (memV, (l, g))
    → state_invariant σ s1 memH (memV, (alist_add id v l, g)).
Proof.
  intros * GAM BOUND INV.
  apply GAM in BOUND.
  eapply state_invariant_same_Γ; eauto.
Qed.

Lemma state_invariant_escape_scope : forall σ v x s1 s2 stH stV,
    Γ s1 ≡ x :: Γ s2 ->
    state_invariant (v::σ) s1 stH stV ->
    state_invariant σ s2 stH stV.
Proof.
  intros * EQ [MEM WF ALIAS1 ALIAS2 ALIAS3].
  destruct stV as (? & ? & ?).
  split.
  - red; intros * LU1 LU2.
    red in MEM.
    specialize (MEM (S n)).
    rewrite EQ, 2nth_error_Sn in MEM.
    specialize (MEM _ _ _ LU1 LU2).
    destruct v0; cbn; auto.
  - repeat intro.
    do 2 red in WF.
    edestruct WF with (n := S n) as (?id & LU).
    rewrite nth_error_Sn;eauto.
    exists id.
    rewrite EQ in LU.
    rewrite nth_error_Sn in LU;eauto.

  - red; intros * LU1 LU2 LU3 LU4.
    specialize (ALIAS1 (S n1) (S n2)).
    rewrite EQ, 2nth_error_Sn in ALIAS1.
    eapply ALIAS1 in LU1; eauto.
  - red; intros * LU1 LU2.
    specialize (ALIAS2 (S n) (S n')).
    rewrite 2nth_error_Sn in ALIAS2.
    eapply ALIAS2 in LU1; eauto.

  - do 2 red. intros * LU1 LU2 LU3 LU4 INEQ IN1 IN2.
    do 2 red in ALIAS3.
    specialize (ALIAS3 id1 ptrv1 id2 ptrv2 (S n1) (S n2)).
    rewrite !EQ, !nth_error_Sn in ALIAS3.
    eapply ALIAS3 in LU1; eauto.

  - red.
    intros * LU.
    eapply (st_id_allocated0 (S n)); eauto.
Qed.

(* TO MOVE *)
Definition uvalue_of_nat k := UVALUE_I64 (Int64.repr (Z.of_nat k)).

Lemma state_invariant_enter_scope_DSHnat : 
  forall σ v prefix x s1 s2 stH mV l g,
    newLocalVar IntType prefix s1 ≡ inr (s2, x) ->
    ~ in_Gamma σ s1 x ->
    l @ x ≡ Some (uvalue_of_nat v) ->
    state_invariant σ s1 stH (mV,(l,g)) ->
    state_invariant (DSHnatVal (Int64.repr (Z.of_nat v))::σ) s2 stH (mV,(l,g)).
Proof.
  intros * EQ GAM LU [MEM WF ALIAS1 ALIAS2 ALIAS3]; inv EQ; cbn in *.
  split.
  - red; intros * LU1 LU2.
    destruct n as [| n].
    + cbn in *; inv LU1; inv LU2; auto.
      cbn; rewrite repr_intval; auto.
    + rewrite nth_error_Sn in LU1.
      cbn in *.
      eapply MEM in LU2; eauto.
  -  do 2 red.
     cbn.
     intros ? [| n] LU'.
     + cbn in LU'.
       inv LU'.
       cbn.
       exists (ID_Local (Name (prefix @@ string_of_nat (local_count s1)))); reflexivity.
     + rewrite nth_error_Sn in LU'.
       rewrite nth_error_Sn.
       apply WF in LU'; auto.

  - red; intros * LU1 LU2 LU3 LU4.
    destruct n1 as [| n1], n2 as [| n2]; auto.
    + exfalso. cbn in *.
      apply GAM.
      inv LU3; eapply mk_in_Gamma; eauto.
    + exfalso.
      apply GAM; inv LU4; eapply mk_in_Gamma; eauto.
    + inv LU3; inv LU4; eapply ALIAS1 in LU1; apply LU1 in LU2; eauto.

  - red; intros * LU1 LU2.
    destruct n as [| n], n' as [| n']; auto.
    + inv LU1.
    + inv LU2.
    + rewrite nth_error_Sn in LU1.
      rewrite nth_error_Sn in LU2.
      eapply ALIAS2 in LU1; apply LU1 in LU2; eauto.

  - do 2 red. intros * LU1 LU2 LU3 LU4 INEQ IN1 IN2.
    cbn in *.
    destruct n1 as [| n1], n2 as [| n2]; auto.
    + cbn in *. inv LU1; inv LU2; inv LU3; inv LU4; auto.
    + cbn in *; inv LU1; inv LU3; eauto.
      cbn in *.
      rewrite LU in IN1; inv IN1.
    + cbn in *; inv LU2; inv LU4.
      cbn in *; rewrite LU in IN2; inv IN2.
    + cbn in *.
      eapply ALIAS3; [exact LU1 | exact LU2 |..]; eauto.
  - intros [| n] * LUn; [inv LUn |].
    eapply st_id_allocated0; eauto.
Qed.

(* TO FIX, although for now it us not used anywhere, so first check if we need it *)
Lemma state_invariant_enter_scope_DSHCType : forall σ v x τ s1 s2 stH mV l g,
    τ ≡ getWFType x DSHCType ->
    Γ s1 ≡ (x,τ) :: Γ s2 ->
    ~ In x (map fst (Γ s2)) ->
    in_local_or_global_scalar l g mV x (dvalue_of_bin v) τ ->
    state_invariant σ s2 stH (mV,(l,g)) ->
    state_invariant (DSHCTypeVal v::σ) s1 stH (mV,(l,g)).
Proof.
(*   intros * -> EQ fresh IN [MEM WF ALIAS1 ALIAS2 ALIAS3]. *)
(*   split. *)
(*   - red; intros * LU1 LU2. *)
(*     destruct n as [| n]. *)
(*     + rewrite EQ in LU2; cbn in *. *)
(*       inv LU1; inv LU2; auto. *)
(*     + rewrite nth_error_Sn in LU1. *)
(*       rewrite EQ, nth_error_Sn in LU2. *)
(*       eapply MEM in LU2; eauto. *)
(*   -  do 2 red. *)
(*      intros ? [| n] LU. *)
(*      + cbn in LU. *)
(*        inv LU. *)
(*        rewrite EQ; cbn; eauto. *)
(*      + rewrite nth_error_Sn in LU. *)
(*        rewrite EQ,nth_error_Sn. *)
(*        apply WF in LU; auto. *)

(*   - red; intros * LU1 LU2 LU3 LU4. *)
(*     destruct n1 as [| n1], n2 as [| n2]; auto. *)
(*     + exfalso. *)
(*       inv LU3; apply GAM. *)
(*       apply nth_error_In in LU2. *)
(*       replace id with (fst (id,τ')) by reflexivity. *)
(*       apply in_map; auto. *)

(*     + exfalso. *)
(*       rewrite EQ, nth_error_Sn in LU1. *)
(*       rewrite EQ in LU2. *)
(*       cbn in *. *)
(*       inv LU2. *)
(*       apply fresh. *)
(*       apply nth_error_In in LU1. *)
(*       replace id with (fst (id,τ)) by reflexivity. *)
(*       apply in_map; auto. *)

(*     + rewrite EQ, nth_error_Sn in LU1. *)
(*       rewrite EQ, nth_error_Sn in LU2. *)
(*       eapply ALIAS1 in LU1; apply LU1 in LU2; eauto. *)
(*       destruct LU2; split; auto. *)

(*   - red; intros * LU1 LU2. *)
(*     destruct n as [| n], n' as [| n']; auto. *)
(*     + inv LU1. *)

(*     + inv LU2. *)


(*     + rewrite nth_error_Sn in LU1. *)
(*       rewrite nth_error_Sn in LU2. *)
(*       eapply ALIAS2 in LU1; apply LU1 in LU2; eauto. *)

(*   - do 2 red. intros * LU1 LU2 LU3 LU4 INEQ. *)
(*     destruct n1 as [| n1], n2 as [| n2]; auto. *)
(*     + cbn in *. *)
(*       inv LU1; inv LU2. *)
(*       admit. *)
(*     + cbn in *; inv LU1. *)
(*       admit. *)
(*     + cbn in *; inv LU2. *)
(*       admit. *)
Admitted.

Lemma state_invariant_enter_scope_DSHPtr :
  forall σ ptrh sizeh ptrv x τ s1 s2 stH mV mV_a l g,
    τ ≡ getWFType (ID_Local x) (DSHPtr sizeh) ->
    Γ s2 ≡ (ID_Local x,τ) :: Γ s1 ->

    (* Freshness *)
    ~ in_Gamma σ s1 x ->
    (* ~ In (ID_Local x) (map fst (Γ s2)) ->          (* The new ident is fresh *) *)
    (forall sz, ~ In (DSHPtrVal ptrh sz) σ) -> (* The new Helix address is fresh *)

    (* We know that a certain ptr has been allocated *)
    allocate mV (DTYPE_Array (Z.to_N (Int64.intval sizeh)) DTYPE_Double) ≡ inr (mV_a, ptrv) ->

    state_invariant σ s1 stH (mV,(l,g)) ->

    state_invariant (DSHPtrVal ptrh sizeh :: σ) s2
                    (memory_set stH ptrh mem_empty)
                    (mV_a, (alist_add x (UVALUE_Addr ptrv) l,g)).
Proof.
  Opaque add_logical_block. Opaque next_logical_key.
  intros * -> EQ GAM fresh alloc [MEM WF ALIAS1 ALIAS2 ALIAS3 ALLOC].
  split.
  - red; intros * LU1 LU2.
    destruct n as [| n].
    + rewrite EQ in LU2; cbn in *.
      inv LU1; inv LU2; eauto.
      exists mem_empty. eexists ptrv. eexists.
      split; auto.
      apply memory_lookup_memory_set_eq.

      split. reflexivity.
      split. red.
      inv alloc.
      rewrite get_logical_block_of_add_to_frame. cbn.
      rewrite get_logical_block_of_add_logical_block.
      
      auto. eexists. eexists. eexists. split; auto.
      reflexivity. cbn. rewrite typ_to_dtyp_D_array. cbn. lia.
      split; auto. inv alloc.
      red.
      rewrite alist_find_add_eq. reflexivity.
      inv alloc.
      intros. inversion H.

    + pose proof LU1 as LU1'.
      pose proof LU2 as LU2'.
      rewrite nth_error_Sn in LU1.
      rewrite EQ, nth_error_Sn in LU2.
      eapply MEM in LU2; eauto.

      (* There is some reasoning on the memory (on [alloc] in particular) to be done here *)
      (* I've allocated a new pointer, and added it to the local environment.
       *)
      pose proof (allocate_correct alloc) as (ALLOC_FRESH & ALLOC_NEW & ALLOC_OLD).
      { destruct v.
        - destruct x0.
          + (* The only complication here is read mV_a *)
            destruct LU2 as (ptr & τ' & TEQ & G & READ).
            exists ptr. exists τ'.
            repeat (split; auto).
            erewrite ALLOC_OLD; eauto.

            eapply can_read_allocated; eauto.
            eapply freshly_allocated_no_overlap_dtyp; eauto.
            eapply can_read_allocated; eauto.
          + cbn. cbn in LU2.
            destruct (Eqv.eqv_dec_p x id) as [EQid | NEQid].
            * do 2 red in EQid; subst.
              (* Need a contradiction *)
              exfalso. apply GAM.
              rewrite EQ, nth_error_Sn in LU2'.
              econstructor; eauto.
            * unfold Eqv.eqv, eqv_raw_id in NEQid.
              rewrite alist_find_neq; eauto.
        - destruct x0.
          + (* The only complication here is read mV_a *)
            destruct LU2 as (ptr & τ' & TEQ & G & READ).
            exists ptr. exists τ'.
            repeat (split; auto).
            erewrite ALLOC_OLD; eauto.

            eapply can_read_allocated; eauto.
            eapply freshly_allocated_no_overlap_dtyp; eauto.
            eapply can_read_allocated; eauto.
          + cbn. cbn in LU2.
            destruct (Eqv.eqv_dec_p x id) as [EQid | NEQid].
            * do 2 red in EQid; subst.
              (* Need a contradiction *)
              exfalso. apply GAM.
              rewrite EQ, nth_error_Sn in LU2'.
              econstructor; eauto.
            * unfold Eqv.eqv, eqv_raw_id in NEQid.
              rewrite alist_find_neq; eauto.
        - destruct LU2 as (bkh & ptr_llvm & τ' & MLUP & TEQ & FITS & INLG & GET).
          exists bkh. exists ptr_llvm. exists τ'.
          assert (ptrh ≢ a) as NEQa.
          { intros CONTRA.
            subst.
            apply nth_error_In in LU1.
            apply (fresh size). auto.
          }
          repeat (split; eauto).
          + rewrite memory_lookup_memory_set_neq; auto.
          + eapply dtyp_fits_after_allocated; eauto.
          + destruct x0; auto.
            destruct (Eqv.eqv_dec_p x id) as [EQid | NEQid].
            * do 2 red in EQid; subst.
              exfalso. apply GAM.
              rewrite EQ, nth_error_Sn in LU2'.
              econstructor; eauto.
            * unfold Eqv.eqv, eqv_raw_id in NEQid.
              cbn.
              rewrite alist_find_neq; eauto.
          + intros i v H.
            unfold get_array_cell in *.

            (* TODO: is there a better way to do this...? *)
            assert ((let
                       '(b, o) := ptr_llvm in
                     match get_logical_block mV_a b with
                     | Some (LBlock _ bk _) => get_array_cell_mem_block bk o (MInt64asNT.to_nat i) 0 DTYPE_Double
                     | None => failwith "Memory function [get_array_cell] called at a non-allocated address"
                     end) ≡
                     (
                         match get_logical_block mV_a (fst ptr_llvm) with
                         | Some (LBlock _ bk _) => get_array_cell_mem_block bk (snd ptr_llvm) (MInt64asNT.to_nat i) 0 DTYPE_Double
                         | None => failwith "Memory function [get_array_cell] called at a non-allocated address"
                         end)).
            { destruct ptr_llvm. cbn. reflexivity. }

            assert ((let
                       '(b, o) := ptr_llvm in
                     match get_logical_block mV b with
                     | Some (LBlock _ bk _) => get_array_cell_mem_block bk o (MInt64asNT.to_nat i) 0 DTYPE_Double
                     | None => failwith "Memory function [get_array_cell] called at a non-allocated address"
                     end) ≡
                     (
                         match get_logical_block mV (fst ptr_llvm) with
                         | Some (LBlock _ bk _) => get_array_cell_mem_block bk (snd ptr_llvm) (MInt64asNT.to_nat i) 0 DTYPE_Double
                         | None => failwith "Memory function [get_array_cell] called at a non-allocated address"
                         end)).
            { destruct ptr_llvm. cbn. reflexivity. }

            rewrite H0.
            erewrite get_logical_block_allocated.
            rewrite <- H1.
            eauto.
            eauto.
            eapply dtyp_fits_allocated; eauto.
      }

  - do 2 red.
    intros ? [| n] LU.
    + cbn in LU.
      inv LU.
      rewrite EQ; cbn; eauto.
      exists (ID_Local x). cbn. reflexivity.
    + rewrite nth_error_Sn in LU.
      rewrite EQ,nth_error_Sn.
      apply WF in LU; auto.

  - red; intros * LU1 LU2 LU3 LU4.
    destruct n1 as [| n1], n2 as [| n2]; auto.

    + exfalso.
      inv LU1; rewrite EQ in LU3; inv LU3.
      rewrite EQ in LU4.
      cbn in LU2.
      cbn in LU4.
      apply GAM; eapply mk_in_Gamma; eauto.
 
    + exfalso.
      inv LU2; rewrite EQ in LU4; inv LU4.
      rewrite EQ in LU3.
      apply GAM; eapply mk_in_Gamma; eauto.

    + rewrite EQ in LU3,LU4; cbn in *.
      f_equal. eapply ALIAS1; eauto.

  - red; intros * LU1 LU2.
    destruct n as [| n], n' as [| n']; auto.
    + cbn in *. inv LU1. exfalso.
      eapply fresh.
      apply nth_error_In in LU2. eauto.
    + cbn in *. inv LU2. exfalso.
      eapply fresh.
      apply nth_error_In in LU1. eauto.
    + cbn in *.
      f_equal; eapply ALIAS2; eauto.

  - cbn in ALIAS3.
    do 2 red. intros * LU1 LU2 LU3 LU4 INEQ IN1 IN2.

    rewrite EQ in *.
    destruct n1 as [| n1], n2 as [| n2]; auto.
    + (* Both pointers are the same *)
      inv LU1; inv LU2; inv LU3; inv LU4.
      contradiction.
    + (* One pointer from Γ s2, one from Γ s1 *)
      inv LU3.
      unfold WF_IRState, evalContext_typechecks in WF.
      pose proof LU2.
      apply WF in H.
      destruct H. cbn in LU4. rewrite LU4 in H.
      cbn in H.
      inv H.

      apply alist_In_add_eq in IN1.
      inv IN1.
      epose proof (MEM _ _ _ _ LU2 LU4).
      destruct v2.
      * destruct x0.
        -- destruct H as (ptr & τ' & TEQ & G & READ).
           inv TEQ.
           rewrite typ_to_dtyp_I in READ.
           rewrite IN2 in G. inv G.
           apply can_read_allocated in READ.
           eapply freshly_allocated_different_blocks in alloc; eauto.
        -- assert (x ≢ id) as NEQ by (intros CONTRA; subst; contradiction).
           apply In_add_ineq_iff in IN2; auto.
           unfold alist_In in IN2.
           cbn in H.
           rewrite IN2 in H.
           inv H.
      * destruct x0.
        -- destruct H as (ptr & τ' & TEQ & G & READ).
           inv TEQ.
           rewrite typ_to_dtyp_D in READ.
           rewrite IN2 in G. inv G.
           apply can_read_allocated in READ.
           eapply freshly_allocated_different_blocks in alloc; eauto.
        -- assert (x ≢ id) as NEQ by (intros CONTRA; subst; contradiction).
           apply In_add_ineq_iff in IN2; auto.
           unfold alist_In in IN2.
           cbn in H.
           rewrite IN2 in H.
           inv H.
      * destruct H as (bk_helix & ptr & τ' & MLUP & WFT & FITS & INLG & GETARRAY).
        destruct x0.
        -- cbn in INLG. rewrite IN2 in INLG. inv INLG.
           apply dtyp_fits_allocated in FITS.
           eapply freshly_allocated_different_blocks in alloc; eauto.
        -- assert (x ≢ id) as NEQ by (intros CONTRA; subst; contradiction).
           apply In_add_ineq_iff in IN2; auto.
           unfold alist_In in IN2.
           cbn in INLG.
           rewrite IN2 in INLG.
           inv INLG.
           apply dtyp_fits_allocated in FITS.
           eapply freshly_allocated_different_blocks in alloc; eauto.
    + (* One pointer from Γ s2, one from Γ s1 *)
      inv LU4.
      unfold WF_IRState, evalContext_typechecks in WF.
      pose proof LU1.
      apply WF in H.
      destruct H. cbn in LU3. rewrite LU3 in H.
      cbn in H.
      inv H.

      apply alist_In_add_eq in IN2.
      inv IN2.
      epose proof (MEM _ _ _ _ LU1 LU3).
      destruct v1.
      * destruct x0.
        -- destruct H as (ptr & τ' & TEQ & G & READ).
           inv TEQ.
           rewrite typ_to_dtyp_I in READ.
           rewrite IN1 in G. inv G.
           apply can_read_allocated in READ.
           eapply freshly_allocated_different_blocks in alloc; eauto.
        -- assert (x ≢ id) as NEQ by (intros CONTRA; subst; contradiction).
           apply In_add_ineq_iff in IN1; auto.
           unfold alist_In in IN1.
           cbn in H.
           rewrite IN1 in H.
           inv H.
      * destruct x0.
        -- destruct H as (ptr & τ' & TEQ & G & READ).
           inv TEQ.
           rewrite typ_to_dtyp_D in READ.
           rewrite IN1 in G. inv G.
           apply can_read_allocated in READ.
           eapply freshly_allocated_different_blocks in alloc; eauto.
        -- assert (x ≢ id) as NEQ by (intros CONTRA; subst; contradiction).
           apply In_add_ineq_iff in IN1; auto.
           unfold alist_In in IN1.
           cbn in H.
           rewrite IN1 in H.
           inv H.
      * destruct H as (bk_helix & ptr & τ' & MLUP & WFT & FITS & INLG & GETARRAY).
        destruct x0.
        -- cbn in INLG. rewrite IN1 in INLG. inv INLG.
           apply dtyp_fits_allocated in FITS.
           eapply freshly_allocated_different_blocks in alloc; eauto.
        -- assert (x ≢ id) as NEQ by (intros CONTRA; subst; contradiction).
           apply In_add_ineq_iff in IN1; auto.
           unfold alist_In in IN1.
           cbn in INLG.
           rewrite IN1 in INLG.
           inv INLG.
           apply dtyp_fits_allocated in FITS.
           eapply freshly_allocated_different_blocks in alloc; eauto.
    + (* Both pointers from Γ s1, can fall back to assumption (ALIAS3) *)
      rewrite nth_error_Sn in LU1, LU2.
      rewrite nth_error_Sn in LU3, LU4.
      assert (id2 ≢ id1) as INEQ' by auto.

      eapply (no_llvm_ptr_aliasing_not_in_gamma (UVALUE_Addr ptrv) ALIAS3 WF GAM).

      eapply LU1.
      eapply LU2.
      all: eauto.
  - unfold id_allocated.
    intros n addr0 val H.
    destruct n.
    + cbn in H. inv H.
      apply mem_block_exists_memory_set_eq.
      reflexivity.
    + cbn in H.
      pose proof (nth_error_In _ _ H).
      assert (addr0 ≢ ptrh) as NEQ.
      { intros CONTRA; subst.
        apply fresh in H0.
        contradiction.
      }

      apply (@mem_block_exists_memory_set_neq _ _ stH mem_empty NEQ).
      eauto.
Qed.

Lemma vellvm_helix_ptr_size:
  forall σ s memH memV ρ g n id (sz : N) dsh_ptr (dsh_sz : Int64.int),
    nth_error (Γ s) n ≡ Some (id, TYPE_Pointer (TYPE_Array sz TYPE_Double)) ->
    nth_error σ n ≡ Some (DSHPtrVal dsh_ptr dsh_sz) ->
    state_invariant σ s memH (memV, (ρ, g)) ->
    sz ≡ Z.to_N (Int64.intval dsh_sz).
Proof.
  intros σ s memH memV ρ g n id sz dsh_ptr dsh_sz GAM SIG SINV.
  apply IRState_is_WF in SINV.
  unfold WF_IRState in SINV.
  unfold evalContext_typechecks in SINV.
  pose proof (SINV (DSHPtrVal dsh_ptr dsh_sz) n SIG) as H.
  destruct H as (id' & NTH).
  cbn in NTH.
  rewrite GAM in NTH.
  inv NTH.
  destruct id'; inv H1; reflexivity.
Qed.

Lemma unsigned_is_zero: forall a, Int64.unsigned a ≡ Int64.unsigned Int64.zero ->
                                  a = Int64.zero.
Proof.
  intros a H.
  unfold Int64.unsigned, Int64.intval in H.
  repeat break_let; subst.
  destruct Int64.zero.
  inv Heqi0.
  unfold equiv, MInt64asNT.NTypeEquiv, Int64.eq, Int64.unsigned, Int64.intval.
  apply Coqlib.zeq_true.
Qed.

Lemma no_local_global_alias_non_pointer:
  forall l g v,
    (forall p, v ≢ UVALUE_Addr p) ->
    no_local_global_alias l g v.
Proof.
  intros l g v PTR.
  unfold no_local_global_alias.
  intros id p0 p' H0 H1.
  specialize (PTR p0).
  contradiction.
Qed.

Ltac solve_alist_in := first [apply In_add_eq | idtac].
Ltac solve_lu :=
  (try now eauto);
  match goal with
  | |- @Maps.lookup _ _ local_env _ ?id ?l ≡ Some _ =>
    eapply memory_invariant_LLU; [| eassumption | eassumption]; eauto
  | h: _ ⊑ ?l |- @Maps.lookup _ _ local_env _ ?id ?l ≡ Some _ =>
    eapply h; solve_lu
  | |- @Maps.lookup _ _ global_env _ ?id ?l ≡ Some _ =>
    eapply memory_invariant_GLU; [| eassumption | eassumption]; eauto
  | _ => solve_alist_in
  end.

Ltac solve_in_gamma :=
  match goal with
  | GAM : nth_error (Γ ?s) ?n ≡ Some (ID_Local ?id, _),
          SIG : nth_error ?σ ?n ≡ Some _ |-
    in_Gamma _ _ ?id
    => econstructor; [eapply SIG | eapply GAM | eauto]
  end.

(* TODO: expand this *)
Ltac solve_lid_bound_between :=
  eapply lid_bound_between_shrink; [eapply lid_bound_between_incLocal | | ]; eauto; solve_local_count.

Ltac solve_not_in_gamma :=
  first [ now eauto
        |
      match goal with
      | GAM : Gamma_safe ?σ ?si ?sf |- 
        ~ in_Gamma ?σ ?si ?id =>
        eapply GAM; solve_lid_bound_between
      end
    | solve [eapply not_in_Gamma_Gamma_eq; [eassumption | solve_not_in_gamma]]
    ].

Hint Resolve state_invariant_memory_invariant : core.
Hint Resolve memory_invariant_GLU memory_invariant_LLU memory_invariant_LLU_AExpr memory_invariant_GLU_AExpr : core.

Hint Resolve is_pure_refl: core.
Hint Resolve local_scope_modif_refl: core.

Hint Resolve genNExpr_Γ : helix_context.
Hint Resolve genMExpr_Γ : helix_context.
Hint Resolve incVoid_Γ        : helix_context.
Hint Resolve incLocal_Γ       : helix_context.
Hint Resolve incBlockNamed_Γ  : helix_context.
Hint Resolve genAExpr_Γ : helix_context.
Hint Resolve genIR_Γ  : helix_context.

(* TODO: expand this *)
Ltac solve_gamma_safe :=
  eapply Gamma_safe_shrink; eauto; try solve_gamma; cbn; solve_local_count.

(* TODO: expand this *)
Ltac solve_local_scope_modif :=
  eauto;
  first
    [ eapply local_scope_modif_refl
    | solve [eapply local_scope_modif_shrink; [eassumption | solve_local_count | solve_local_count]]
    | solve [eapply local_scope_modif_add'; [solve_lid_bound_between | solve_local_scope_modif]]
    | eapply local_scope_modif_trans; cycle 2; eauto; solve_local_count
    ].

Ltac solve_gamma_preserved :=
  first
    [ solve [eapply Gamma_preserved_refl]
    | eapply Gamma_preserved_add_not_in_Gamma; [solve_gamma_preserved | solve_not_in_gamma]
    ].

Opaque alist_add.

(* TODO: move these *)
Lemma in_local_or_global_scalar_not_in_gamma :
  forall r v ρ g m id v_id τ σ s,
    in_Gamma σ s id ->
    ~ in_Gamma σ s r ->
    in_local_or_global_scalar ρ g m (ID_Local id) v_id τ ->
    in_local_or_global_scalar (alist_add r v ρ) g m (ID_Local id) v_id τ.
Proof.
  intros r v ρ g m id v_id τ σ s GAM NGAM INLG.
  destruct (Eqv.eqv_dec_p r id) as [EQ | NEQ].
  - do 2 red in EQ.
    subst.
    contradiction.
  - unfold Eqv.eqv, eqv_raw_id in NEQ.
    cbn in *.
    erewrite alist_find_neq; eauto.
Qed.

(* TODO: move this? *)
Lemma incLocal_id_neq :
  forall s1 s2 s3 s4 id1 id2,
    incLocal s1 ≡ inr (s2, id1) ->
    incLocal s3 ≡ inr (s4, id2) ->
    local_count s1 ≢ local_count s3 ->
    id1 ≢ id2.
Proof.
  intros s1 s2 s3 s4 id1 id2 GEN1 GEN2 COUNT.
  eapply incLocalNamed_count_gen_injective.
  symmetry; eapply GEN1.
  symmetry; eapply GEN2.
  solve_local_count.
  solve_prefix.
  solve_prefix.
Qed.

Lemma incLocal_id_neq_flipped :
  forall s1 s2 s3 s4 id1 id2,
    incLocal s1 ≡ inr (s2, id1) ->
    incLocal s3 ≡ inr (s4, id2) ->
    local_count s1 ≢ local_count s3 ->
    id2 ≢ id1.
Proof.
  intros s1 s2 s3 s4 id1 id2 GEN1 GEN2 COUNT.
  intros EQ. symmetry in EQ. revert EQ.
  eapply incLocal_id_neq; eauto.
Qed.

Lemma in_gamma_not_in_neq :
  forall σ s id r,
    in_Gamma σ s id ->
    ~ in_Gamma σ s r ->
    id ≢ r.
Proof.
  intros σ s id r GAM NGAM.
  destruct (Eqv.eqv_dec_p r id) as [EQ | NEQ].
  - do 2 red in EQ.
    subst.
    contradiction.
  - unfold Eqv.eqv, eqv_raw_id in NEQ.
    eauto.
Qed.


Ltac solve_id_neq :=
  first [ solve [eapply incLocal_id_neq; eauto; solve_local_count]
        | solve [eapply in_gamma_not_in_neq; [solve_in_gamma | solve_not_in_gamma]]
        ].

Ltac solve_local_lookup :=
  first
    [ now eauto
    | solve [erewrite alist_find_add_eq; eauto]
    | solve [erewrite alist_find_neq; [solve_local_lookup|solve_id_neq]]
    ].

Ltac solve_in_local_or_global_scalar :=
  first
    [ now eauto
    | solve [eapply in_local_or_global_scalar_not_in_gamma; [solve_in_gamma | solve_not_in_gamma | solve_in_local_or_global_scalar]]
    ].

Hint Resolve state_invariant_memory_invariant state_invariant_WF_IRState : core.

Lemma local_scope_preserved_bound_earlier :
  forall s1 s2 s3 x v l l',
    lid_bound s1 x ->
    s1 <<= s2 ->
    local_scope_preserved s2 s3 l l' ->
    local_scope_preserved s2 s3 l (Maps.add x v l').
Proof.
  intros s1 s2 s3 x v l l' BOUND LT PRES.
  unfold local_scope_preserved.
  intros id BETWEEN.

  epose proof (lid_bound_earlier BOUND BETWEEN LT) as NEQ.
  unfold local_scope_preserved in PRES.
  setoid_rewrite maps_add_neq; eauto.
Qed.

Ltac solve_lid_bound :=
  eapply incLocal_lid_bound; eauto.

Ltac solve_local_scope_preserved :=
  first [ apply local_scope_preserved_refl
        | eapply local_scope_preserved_bound_earlier;
          [solve_lid_bound | solve_local_count | solve_local_scope_preserved]
        ].

Ltac solve_state_invariant := eauto with SolveStateInv.
Hint Extern 2 (state_invariant _ _ _ _) => eapply state_invariant_incBlockNamed; [eassumption | solve_state_invariant] : SolveStateInv.
Hint Extern 2 (state_invariant _ _ _ _) => eapply state_invariant_incLocal; [eassumption | solve_state_invariant] : SolveStateInv.
Hint Extern 2 (state_invariant _ _ _ _) => eapply state_invariant_incLocalNamed; [eassumption | solve_state_invariant] : SolveStateInv.
Hint Extern 2 (state_invariant _ _ _ _) => eapply state_invariant_incVoid; [eassumption | solve_state_invariant] : SolveStateInv.
