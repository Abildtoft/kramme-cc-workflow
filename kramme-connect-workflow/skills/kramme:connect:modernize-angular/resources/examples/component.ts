import {
  ChangeDetectionStrategy,
  Component,
  inject,
  Input,
} from "@angular/core";
import { animate, style, transition, trigger } from "@angular/animations";
import { ComponentNameStore } from "./component-name.store";

@Component({
  selector: "co-component-name",
  templateUrl: "./component-name.component.html",
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [ComponentNameStore],
  imports: [
    // Only what you need
  ],
  animations: [
    trigger("slideDown", [
      transition(":enter", [
        style({ height: "0", opacity: 0, overflow: "hidden" }),
        animate("300ms ease-out", style({ height: "*", opacity: 1 })),
      ]),
      transition(":leave", [
        style({ height: "*", opacity: 1, overflow: "hidden" }),
        animate("300ms ease-in", style({ height: "0", opacity: 0 })),
      ]),
    ]),
  ],
})
export class ComponentNameComponent {
  readonly #componentStore = inject(ComponentNameStore);

  @Input() set data(data: DataType) {
    if (data) {
      this.#componentStore.initializeForm(data);
    }
  }

  readonly form = this.#componentStore.form;
  readonly data$ = this.#componentStore.currentData$;

  saveChanges(): void {
    this.#componentStore.saveChanges();
  }

  cancelChanges(): void {
    this.#componentStore.cancelChanges();
  }
}
