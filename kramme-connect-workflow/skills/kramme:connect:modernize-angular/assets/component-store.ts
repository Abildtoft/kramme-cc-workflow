import { inject, Injectable } from "@angular/core";
import { ComponentStore } from "@ngrx/component-store";
import { Store } from "@ngrx/store";
import { FormControl, FormGroup, Validators } from "@angular/forms";
import { filter, pipe, switchMap, tap, withLatestFrom } from "rxjs";

// Define form controls interface
export interface ComponentNameFormControls {
  field1: FormControl<string>;
  field2: FormControl<boolean>;
}

// Define state interface
interface ComponentNameState {
  readonly currentData: DataType | null;
}

const initialState: ComponentNameState = {
  currentData: null,
};

@Injectable()
export class ComponentNameStore extends ComponentStore<ComponentNameState> {
  readonly #store = inject(Store);

  // Selectors
  readonly currentData$ = this.select((state) => state.currentData);
  readonly externalData$ = this.#store.select(getExternalData.selector);

  // Form definition
  readonly form = new FormGroup<ComponentNameFormControls>({
    field1: new FormControl<string>("", {
      validators: [Validators.required],
      nonNullable: true,
    }),
    field2: new FormControl<boolean>(false, { nonNullable: true }),
  });

  // Updaters
  readonly setCurrentData = this.updater<DataType>(
    (state, data): ComponentNameState => ({
      ...state,
      currentData: data,
    })
  );

  // Effects - use pipe() directly
  readonly initializeForm = this.effect<DataType>(
    pipe(
      tap((data: DataType) => {
        this.setCurrentData(data);
        this.form.reset(data);
        this.#applyConditionalDisabling(this.form);
      })
    )
  );

  readonly saveChanges = this.effect<void>(
    pipe(
      tap(() => {
        this.#store.dispatch(updateAction.start(this.form.getRawValue()));
      })
    )
  );

  readonly cancelChanges = this.effect<void>(
    pipe(
      withLatestFrom(this.currentData$),
      filter((tuple): tuple is [void, DataType] => tuple[1] !== null),
      tap(([, data]) => {
        this.form.reset(data);
        this.#applyConditionalDisabling(this.form);
      })
    )
  );

  // Call after form reset and in an effect watching the parent field
  readonly applyConditionalDisabling = this.effect<void>(
    pipe(
      switchMap(() => this.form.controls.field1.valueChanges),
      tap(() => {
        this.#applyConditionalDisabling(this.form);
      })
    )
  );

  // Private methods
  #applyConditionalDisabling(form: FormGroup<ComponentNameFormControls>): void {
    // Conditional enabling/disabling logic
  }

  constructor() {
    super(initialState);
    // Initialize effects that don't take parameters
    this.applyConditionalDisabling();
  }
}
