import type { AllocationCell, AllocationOperation } from "@/storage/operation";

export type StorageAllocation = {
    ops: AllocationOperation[];
    header: { value: number; bits: number } | null;
    size: { bits: number; refs: number };
    root: AllocationCell;
};
