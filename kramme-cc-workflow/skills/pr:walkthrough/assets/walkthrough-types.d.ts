// Compile-time contracts for the walkthrough runtime's used D3 surface.
export interface Media {
  src?: unknown;
  url?: unknown;
  path?: unknown;
  label?: unknown;
  title?: unknown;
  alt?: unknown;
  type?: unknown;
}
export interface GraphNode {
  id: string;
  x?: number;
  y?: number;
  width?: unknown;
  height?: unknown;
  title?: unknown;
  summary?: unknown;
  color?: unknown;
  details?: unknown[];
  files?: { path?: unknown; label?: unknown; url?: unknown }[];
  comments?: { author?: unknown; body?: unknown }[];
  links?: { url?: unknown; label?: unknown }[];
  media?: (string | Media)[];
}
export interface GraphEdge {
  source: string;
  target: string;
  id?: unknown;
  label?: unknown;
}
export interface Graph {
  id: string;
  label?: unknown;
  color?: unknown;
  nodes?: GraphNode[];
  edges?: GraphEdge[];
  tour?: { nodeId?: string; body?: unknown; summary?: unknown }[];
}
export interface WalkthroughData {
  meta?: { baseRef?: unknown; headRef?: unknown; prUrl?: unknown } | null;
  graphs?: Graph[];
}
interface ZoomTransform {
  translate(x: number, y: number): ZoomTransform;
  scale(factor: number): ZoomTransform;
  toString(): string;
}
type Attribute = string | number | boolean | ZoomTransform | null;
type Callback<E extends Element, D, R> = (
  this: E,
  datum: D,
  index: number,
  nodes: E[],
) => R;
interface Selection<E extends Element, D = unknown> {
  append<K extends keyof SVGElementTagNameMap>(
    name: K,
  ): Selection<SVGElementTagNameMap[K], D>;
  append(name: "xhtml:div"): Selection<HTMLDivElement, D>;
  attr(
    name: string,
    value: Attribute | undefined | Callback<E, D, Attribute | undefined>,
  ): this;
  selectAll(selector: string): Selection<Element>;
  data<N>(
    values: N[],
    key: (datum: N, index: number) => string,
  ): Selection<E, N>;
  join<K extends keyof SVGElementTagNameMap>(
    name: K,
  ): Selection<SVGElementTagNameMap[K], D>;
  remove(): this;
  each(callback: Callback<E, D, void>): this;
  text(value: string): this;
  html(value: string): this;
  on(
    name: "click",
    callback: (this: E, event: MouseEvent, datum: D) => void,
  ): this;
  call<A extends unknown[]>(
    callback: (selection: this, ...args: A) => void,
    ...args: A
  ): this;
  transition(): Transition<E, D>;
}
interface Transition<E extends Element, D> {
  duration(milliseconds: number): this;
  call<A extends unknown[]>(
    callback: (transition: this, ...args: A) => void,
    ...args: A
  ): this;
}
interface ZoomBehavior {
  (selection: Selection<SVGSVGElement>): void;
  scaleExtent(extent: [number, number]): this;
  on(
    name: "zoom",
    callback: (event: { transform: ZoomTransform }) => void,
  ): this;
  transform(
    selection: Selection<SVGSVGElement> | Transition<SVGSVGElement, unknown>,
    transform: ZoomTransform,
  ): void;
  scaleBy(
    selection: Selection<SVGSVGElement> | Transition<SVGSVGElement, unknown>,
    factor: number,
  ): void;
}
declare global {
  const d3: {
    select<E extends Element>(element: E): Selection<E>;
    zoom(): ZoomBehavior;
    zoomIdentity: ZoomTransform;
  };
}
