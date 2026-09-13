# Scope closure

Load this for every drafted plan before the product and quality review. The purpose is to prove that the exact-file scope is complete enough to deliver the stated end state. A drift check proves freshness only for paths already listed; it cannot detect an omitted file.

## Build the required edit surface

1. Convert each Goal, Intended End State statement, Product / Quality Bar outcome, implementation step, and completion criterion into an observable obligation.
2. Trace each obligation end to end through the applicable live repository path. For runtime behavior, start at the externally visible entry point and follow the actual runtime path to the final state/output boundary. For build tooling, follow the build entry point to the produced artifact. For documentation, copy, QA, audit, and workflow or process changes, trace the owning artifact or workflow entry point to its reviewer, consumer, or verifiable output. Do not invent a runtime path for work that has none. Inspect every applicable layer, including:
   - routes, controllers, commands, handlers, public exports, serializers, and manual response mappers;
   - DTOs, input/output types, schemas, validators, services, persistence entities, queries, policies, and configuration;
   - all callers, implementers, consumers, and writers affected by a changed signature, required field, schema, enum, event, or return shape;
   - focused tests at each affected boundary plus fixtures, factories, mocks, snapshots, examples, and generated artifacts;
   - migrations, backfills, compatibility shims, rollout code, and documentation when the claimed outcome requires them.
3. Search the whole repository for every symbol and contract that the plan changes. Use exact symbol searches plus nearby semantic terms when manual mapping, reflection, string keys, registration, or generated code can hide a typed reference. Do not stop after finding the files named by the source report.
4. Classify every discovered candidate path:
   - `modify` — the file must change for an obligation to hold;
   - `verify-only` — inspect or run it, but no edit is expected; record why the current behavior already satisfies the new contract;
   - `irrelevant` — record the concrete reason the match is outside this behavior path.
5. Put every `modify` path in **In Scope**. Put tempting `verify-only` or deliberately deferred paths in **Out of Scope** with their evidence-based reason. Do not place a required edit in **Out of Scope** merely to keep the PR small; when adding it would change the confirmed theme boundary, apply the mode-aware boundary rule below.

## Contract-change rules

For a changed input, output, schema, persisted shape, or public API contract:

- Enumerate all repository references and classify each one. A sampling of callers is insufficient.
- If a new field is required, account for every existing constructor, writer, fixture, mock, and call site. If it is optional or defaulted, cite the compatibility mechanism that makes unchanged callers valid.
- Verify both directions of manual translation. A DTO/service change is incomplete when a controller, serializer, mapper, adapter, or client still drops the field.
- Include the closest tests for each boundary that must expose, accept, persist, filter, or return the changed value.
- Treat migrations, generated clients/types, snapshots, and checked-in schema artifacts as required scope when repository conventions or build tooling require them. Otherwise record the command or evidence proving they remain unchanged.

## Closure evidence

Populate the plan's **Scope Closure Evidence** table. Use one row per obligation or contract surface, splitting rows when classifications differ.

| Obligation / changed contract | Applicable path traced | Repository search / references | Path disposition | Proof |
| --- | --- | --- | --- | --- |
| Observable behavior or contract | Runtime, build, artifact, reviewer, or verification path -> verifiable output | Symbols/keys searched and callers found | `path` — modify / verify-only / irrelevant | Test, inspection, compatibility rule, or generated-artifact check |

The scope closes only when all of these are true:

- Every acceptance criterion has an implementation path and a proof path.
- Every step's named edit appears in **In Scope**, and every **In Scope** file is justified by at least one obligation.
- Every repository reference to a changed contract is classified.
- Applicable runtime boundary files that expose or translate behavior are accounted for, even when the source finding omitted them.
- Tests and auxiliary artifacts affected by the change are either in scope or supported by concrete verify-only evidence.
- No required edit appears in **Out of Scope**.

If any condition fails, continue recon and revise the scope only while the confirmed theme boundary remains intact. In findings mode, if closure crosses a theme boundary or makes the plan oversized, return to Phase 2, split or resequence there, rebuild dependency labels, and repeat the required confirmation before writing files. In pre-clustered handoff mode, never expand, split, merge, or resequence the fixed themes yourself; stop and request a corrected handoff. If closure contradicts an explicit non-goal or requires an unknown product decision, stop with `MISSING REQUIREMENT:`. Never emit a knowingly incomplete exact-file contract.
