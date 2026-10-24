import type { BackendApi } from "@/lib/backend/api";
import type { ModelRow, ModelUsageRow } from "@/lib/backend/database.types";
import { modelFromRow } from "@/lib/backend/mappers";
import type { AiModel } from "@/lib/domain/types";

// The model list is public (enabled models only, per RLS); the real
// ollama_model name is never exposed to the client.

export async function listModels(api: BackendApi): Promise<AiModel[]> {
  const rows = await api.select<ModelRow>("models", { orderBy: "sort", ascending: true });
  return rows.map(modelFromRow);
}

export interface ModelUsage {
  modelId: string;
  used: number;
}

/** The signed-in user's reply counts for today (UTC). RLS scopes to the user. */
export async function listTodayUsage(api: BackendApi): Promise<ModelUsage[]> {
  const today = new Date().toISOString().slice(0, 10); // UTC date
  const rows = await api.select<ModelUsageRow>("model_usage", { eq: { day: today } });
  return rows.map((r) => ({
    modelId: r.model_id,
    used: r.used,
  }));
}

/** Free replies left for a model today; null when the model has no limit. */
export function freeRepliesLeft(model: AiModel, usage: ModelUsage[]): number | null {
  if (model.dailyFreeReplies == null) return null;
  const used = usage.find((u) => u.modelId === model.id)?.used ?? 0;
  return Math.max(model.dailyFreeReplies - used, 0);
}
