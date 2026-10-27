export type Organization = { alias: string; key: string; fingerprint: string };
export type PoolEntry = {
  fingerprint: string;
  exhausted_at: number | null;
  recheck_after: number | null;
};
export type PoolState = {
  schema_version: 1;
  active: string | null;
  organizations: Record<string, PoolEntry>;
};
export type TraceEvent = { event: string; detail: string };
export type Attempt = {
  case_id: string;
  organization: string;
  started_at: number;
  outcome: string;
  model: string | null;
  cost_usd: number | null;
  trace: TraceEvent[];
};
export type SavedPrediction = {
  text: string;
  organization: string;
  model: string;
};
export type RunState = {
  schema_version: 1;
  id: string;
  fingerprint: string;
  model: string;
  sdk_version: string;
  commit: string;
  created_at: number;
  updated_at: number;
  case_ids: string[];
  status: "RUNNING" | "COMPLETE" | "PAUSED_NO_CREDITS" | "ERROR";
  completed: Record<string, SavedPrediction>;
  attempts: Attempt[];
};
export type AdapterContext = {
  adapter_version: number;
  skill_path: string;
  item: {
    id: string;
    input_skill_path?: string;
    input_skill_text?: string | null;
  };
};
export type LiveOptions = {
  organizations: string;
  model: string;
  split: string;
  stateDir: string;
  runId?: string;
  dryRun: boolean;
  attemptTimeout: number;
  caseTimeout: number;
  maxTurns: number;
};
