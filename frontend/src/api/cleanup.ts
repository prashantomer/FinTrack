import type { ApiResponse } from '@/types'
import client from './client'

export type CleanupSector =
  | 'transactions'
  | 'investments'
  | 'holdings'
  | 'accounts'
  | 'term_accounts'
  | 'platform_accounts'
  | 'user_instruments'
  | 'import_batches'
  | 'assistant_messages'
  | 'account_audits'

export interface CleanupConfig {
  sectors:        CleanupSector[]
  date_from?:     string
  date_to?:       string
  source?:        'manual' | 'imported'
  account_ids?:   number[]
  active?:        boolean
  tags_any?:      string[]
  reset_balances?: boolean
}

export interface CleanupPreviewSector {
  sector:    CleanupSector
  before:    number   // current count of all records in this sector
  to_delete: number   // how many match the wizard filters
  after:     number   // before - to_delete (what remains)
  samples:   string[]
}

export interface CleanupBalanceResetEntry {
  id:       number
  nickname: string
  before:   number
  after:    number
}

export interface CleanupPreviewResponse {
  sectors:       CleanupPreviewSector[]
  total:         number
  balance_reset: CleanupBalanceResetEntry[]
}

export interface CleanupExecuteResponse {
  deleted: Partial<Record<CleanupSector, number>>
  total:   number
}

export async function previewCleanup(config: CleanupConfig): Promise<CleanupPreviewResponse> {
  const res = await client.post<ApiResponse<CleanupPreviewResponse>>('/cleanup/preview', config)
  return res.data.data
}

export async function executeCleanup(config: CleanupConfig): Promise<CleanupExecuteResponse> {
  const res = await client.post<ApiResponse<CleanupExecuteResponse>>('/cleanup/execute', {
    ...config,
    confirm: 'DELETE',
  })
  return res.data.data
}
