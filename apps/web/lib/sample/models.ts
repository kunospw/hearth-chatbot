import type { AiModel } from "@/lib/domain/types";

// Preview model list (the real list comes from the models table when signed in).
export const sampleModels: AiModel[] = [
  { id: "ember", name: "Ember", description: "Fast and warm — everyday roleplay.", dailyFreeReplies: 2, busy: false },
  { id: "lumen", name: "Lumen", description: "Balanced and expressive.", dailyFreeReplies: 40, busy: false },
  { id: "atlas", name: "Atlas Pro", description: "The deepest, most detailed replies.", dailyFreeReplies: null, busy: true },
];
