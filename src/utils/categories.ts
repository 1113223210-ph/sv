export const GUIDE_CATEGORIES = {
  'sv': { label: 'SystemVerilog', icon: '⚡', order: 1 },
  'uvm': { label: 'UVM验证', icon: '🔬', order: 2 },
  'soc': { label: 'SoC设计', icon: '🏗️', order: 3 },
} as const;

export type CategorySlug = keyof typeof GUIDE_CATEGORIES;
