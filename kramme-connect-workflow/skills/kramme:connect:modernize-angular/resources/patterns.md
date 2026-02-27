# Common Angular Modernization Patterns

## Conditional Field Disabling

- **ALWAYS** create a private method for conditional logic
- **ALWAYS** use `{ emitEvent: false }` when programmatically enabling/disabling controls
- **ALWAYS** call after form reset and in an effect watching the parent field

```typescript
#applyConditionalDisabling(form: FormGroup<FormControls>): void {
  const parentValue = form.controls.parentField.value;

  if (!parentValue) {
    form.controls.childField.disable({ emitEvent: false });
  } else {
    form.controls.childField.enable({ emitEvent: false });
  }
}

// Call after form reset and in an effect watching the parent field
readonly applyConditionalDisabling = this.effect<void>(
  pipe(
    switchMap(() => this.form.controls.parentField.valueChanges),
    tap(() => {
      this.#applyConditionalDisabling(this.form);
    })
  )
);
```

## Form Controls with nonNullable

- **ALWAYS** add `nonNullable: true` to form controls to ensure type safety
- **NOTE**: This prevents the form control value from being `null` after reset

```typescript
readonly form = new FormGroup<ComponentNameFormControls>({
  field1: new FormControl<string>('', {
    validators: [Validators.required],
    nonNullable: true // ← ALWAYS include this
  }),
  field2: new FormControl<boolean>(false, { nonNullable: true }),
});
```
