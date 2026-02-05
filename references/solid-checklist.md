# SOLID Principles Checklist

Reference checklist for architectural reviews. Use this to evaluate code changes for SOLID compliance.

## Single Responsibility Principle (SRP)

**Question:** "What is the single reason this module would change?"

**Warning Signs:**
- Module handles multiple unrelated concerns
- Class has methods in different abstraction domains
- File imports from many unrelated modules
- Changes in one area require changes in unrelated methods

## Open/Closed Principle (OCP)

**Question:** "Can I add a new variant without touching existing code?"

**Warning Signs:**
- Switch statements that grow with each new feature
- If-else chains checking concrete types
- Modification of existing code to add new behavior
- Spreading changes across multiple files for new features

## Liskov Substitution Principle (LSP)

**Question:** "Can I swap any subclass transparently?"

**Warning Signs:**
- Subclasses checking concrete types
- Subclasses weakening preconditions or strengthening postconditions
- Methods that behave differently based on subtype
- Inheritance used for code reuse rather than polymorphism

## Interface Segregation Principle (ISP)

**Question:** "Do all implementers use all methods?"

**Warning Signs:**
- Large interfaces with many methods
- Implementations with empty or no-op methods
- Clients depending on methods they don't use
- "Fat" interfaces that force unnecessary dependencies

## Dependency Inversion Principle (DIP)

**Question:** "Can I swap the implementation without changing business logic?"

**Warning Signs:**
- High-level modules importing low-level concrete classes
- Direct instantiation of infrastructure in business logic
- Tight coupling to specific frameworks or libraries
- Missing abstractions at module boundaries

---

## Common Code Smells

### Long Methods
Methods exceeding 30 lines often violate SRP.

### Feature Envy
Methods that use more data from other classes than their own.

### Data Clumps
Groups of data that appear together repeatedly should be extracted.

### Primitive Obsession
Using primitives instead of domain types (e.g., `string` for email).

### Shotgun Surgery
A single change requires edits across many classes.

### Divergent Change
One class is changed for multiple unrelated reasons.

### Dead Code
Unused code that adds cognitive load.

### Speculative Generality
Abstractions created for hypothetical future needs.

### Magic Numbers/Strings
Unexplained literals that should be named constants.

---

## Refactoring Heuristics

1. **Split by responsibility, not size** - Extract when responsibilities differ, not just when code is long
2. **Introduce abstractions when needed** - Don't create interfaces for single implementations
3. **Keep changes incremental** - Refactor in small, verifiable steps
4. **Preserve behavior through tests** - Ensure tests pass after each refactoring step
5. **Prioritize clear naming** - Names should reveal intent
6. **Favor composition over inheritance** - Prefer delegation to subclassing
7. **Use type systems** - Let types prevent invalid states
