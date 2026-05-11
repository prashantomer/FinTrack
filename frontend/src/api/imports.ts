import type { ApiResponse, ImportBatch, ImportListResponse, ImportType } from '@/types'
import client from './client'

export async function listImports(page = 1, pageSize = 20): Promise<ImportListResponse> {
  const res = await client.get<ApiResponse<ImportBatch[]>>('/imports', {
    params: { page, page_size: pageSize },
  })
  return {
    items:     res.data.data,
    total:     (res.data.meta_data.total as number) ?? 0,
    page:      (res.data.meta_data.page  as number) ?? page,
    page_size: (res.data.meta_data.page_size as number) ?? pageSize,
  }
}

export async function getImport(id: number): Promise<ImportBatch> {
  const res = await client.get<ApiResponse<ImportBatch>>(`/imports/${id}`)
  return res.data.data
}

export interface CreateImportOptions {
  /**
   * For bank-statement Excel uploads (ICICI, etc.) where the file does not
   * carry per-row account info. Format: "account:<id>" or "term_account:<id>".
   */
  linkedAccount?: string
  /**
   * Policy for what to do when the source file's last running balance
   * disagrees with the computed account.balance after import. Defaults to
   * "ask" (pause and surface the gap in the UI for manual resolution).
   */
  onBalanceMismatch?: 'ask' | 'adjust' | 'fail'
}

export async function createImport(
  importType: ImportType,
  file: File,
  opts: CreateImportOptions = {},
): Promise<ImportBatch> {
  const form = new FormData()
  form.append('import_type', importType)
  form.append('file', file)
  if (opts.linkedAccount) form.append('linked_account', opts.linkedAccount)
  if (opts.onBalanceMismatch) form.append('on_balance_mismatch', opts.onBalanceMismatch)
  const res = await client.post<ApiResponse<ImportBatch>>('/imports', form, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
  return res.data.data
}

export async function resolveImport(
  importId: number,
  actionChoice: 'adjust' | 'abort',
): Promise<ImportBatch> {
  const res = await client.post<ApiResponse<ImportBatch>>(`/imports/${importId}/resolve`,
    { action_choice: actionChoice })
  return res.data.data
}

export function downloadTemplate(importType: ImportType) {
  const token = localStorage.getItem('token')
  const url   = `/api/v1/imports/template/${importType}`
  const a     = document.createElement('a')
  a.href      = token ? `${url}?token=${encodeURIComponent(token)}` : url
  a.download  = `${importType}_import_template.csv`
  // Use fetch so the auth header is sent properly, then trigger download
  fetch(url, { headers: { Authorization: `Bearer ${token}` } })
    .then(r => r.blob())
    .then(blob => {
      const href = URL.createObjectURL(blob)
      a.href     = href
      document.body.appendChild(a)
      a.click()
      document.body.removeChild(a)
      URL.revokeObjectURL(href)
    })
    .catch(() => {})
}
