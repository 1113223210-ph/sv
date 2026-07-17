import type { CategorySlug } from './categories';

export interface ModuleMeta {
  /** 模块中文标题 */
  title: string;
  /** 简短描述 */
  description: string;
  /** 主题色（与 GuideSidebar 的 gradientMap 一致） */
  color: string;
  /** 学习建议 */
  tips: string[];
  /** 前置要求（简短描述） */
  prerequisites?: string;
}

export const MODULE_METADATA: Partial<Record<CategorySlug, ModuleMeta>> = {
  sv: {
    title: 'SystemVerilog',
    description:
      '从语法基础到面向对象编程，系统掌握 SystemVerilog 硬件描述与验证语言，为 UVM 验证和 SoC 设计打下坚实基础。',
    color: '#3B82F6',
    tips: [
      '建议按顺序学习，先掌握语法基础再进入面向对象',
      '多动手写代码，每个知识点都对应真实的硬件电路',
      'class 和 randomize 是后续 UVM 学习的关键',
    ],
  },
  uvm: {
    title: 'UVM验证',
    description:
      '基于 UVM 方法学，掌握工业级验证环境的搭建，包括 driver、monitor、scoreboard 等核心组件的使用。',
    color: '#10B981',
    tips: [
      '建议先完成 SV 语法和 class 部分的学习',
      '结合 design.sv 和 testbench.sv 实例理解 UVM 组件',
      '重点理解 factory、phase、config_db 等核心机制',
    ],
    prerequisites: 'SystemVerilog 基础（尤其是 class 和 randomize）',
  },
  soc: {
    title: 'SoC设计',
    description:
      '从 SoC 基本架构到总线协议，再到入门级和进阶级小模块练习，逐步掌握数字系统设计的核心技能。',
    color: '#F59E0B',
    tips: [
      '建议先了解 SoC 基本架构和总线协议',
      '入门级练习适合巩固基础，进阶级练习适合提升实战能力',
      '每个小模块都是真实项目中的常见组件',
    ],
    prerequisites: 'SystemVerilog 基础',
  },
};

/** category slug → URL 前缀映射 */
export const CATEGORY_URL_PREFIX: Partial<Record<CategorySlug, string>> = {
  sv: '/sv',
  uvm: '/uvm',
  soc: '/soc',
};
