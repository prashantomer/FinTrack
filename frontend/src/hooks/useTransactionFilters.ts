import { useState } from 'react'
import { useDebounce } from './useDebounce'
import type { RecordSource, TransactionType } from '@/types'

export const PAGE_SIZE_OPTIONS = [ 15, 30, 50, 100 ] as const
export const DEFAULT_PAGE_SIZE = 30

export type TransactionSortBy = 'date' | 'account'
export type SortDir = 'asc' | 'desc'

export interface TransactionFilterParams {
  page:      number
  page_size: number
  type?:     TransactionType
  date_from?: string
  date_to?:   string
  search?:    string
  source?:    RecordSource
  linked_account_type?: 'Account' | 'TermAccount'
  linked_account_id?:   number
  sort_by?:  TransactionSortBy
  sort_dir?: SortDir
}

export function useTransactionFilters() {
  const [page, setPage]            = useState(1)
  const [pageSize, setPageSizeRaw] = useState<number>(DEFAULT_PAGE_SIZE)
  const [type, setTypeRaw]         = useState<string>('all')
  const [source, setSourceRaw]     = useState<string>('all')
  const [account, setAccountRaw]   = useState<string>('all')         // "account:N" | "term_account:N" | "all"
  const [sortBy, setSortByRaw]     = useState<TransactionSortBy>('date')
  const [sortDir, setSortDirRaw]   = useState<SortDir>('desc')
  const [dateFrom, setDateFromRaw] = useState('')
  const [dateTo, setDateToRaw]     = useState('')
  const [searchInput, setSearchInputRaw] = useState('')
  const debouncedSearch = useDebounce(searchInput, 350)

  // Polymorphic linked-account selector — backend wants (linked_account_type,
  // linked_account_id) but the dropdown is simpler with one string.
  const accountParams: Pick<TransactionFilterParams, 'linked_account_type' | 'linked_account_id'> = (() => {
    if (account === 'all') return {}
    const [ kind, id ] = account.split(':')
    if (!kind || !id) return {}
    return {
      linked_account_type: (kind === 'account' ? 'Account' : 'TermAccount') as 'Account' | 'TermAccount',
      linked_account_id:   Number(id),
    }
  })()

  const params: TransactionFilterParams = {
    page,
    page_size: pageSize,
    ...(type   !== 'all' && { type:   type   as TransactionType }),
    ...(source !== 'all' && { source: source as RecordSource }),
    ...accountParams,
    ...(dateFrom        && { date_from: dateFrom }),
    ...(dateTo          && { date_to:   dateTo }),
    ...(debouncedSearch && { search:    debouncedSearch }),
    sort_by:  sortBy,
    sort_dir: sortDir,
  }

  function reset() {
    setTypeRaw('all'); setSourceRaw('all'); setAccountRaw('all')
    setDateFromRaw(''); setDateToRaw(''); setSearchInputRaw('')
    setSortByRaw('date'); setSortDirRaw('desc')
    setPage(1)
  }

  const active = type !== 'all'
                 || source !== 'all'
                 || account !== 'all'
                 || !!dateFrom || !!dateTo
                 || !!debouncedSearch

  return {
    params,
    page, setPage,
    pageSize,
    setPageSize: (v: number) => { setPageSizeRaw(v); setPage(1) },
    type,
    setType:     (v: string) => { setTypeRaw(v);     setPage(1) },
    source,
    setSource:   (v: string) => { setSourceRaw(v);   setPage(1) },
    account,
    setAccount:  (v: string) => { setAccountRaw(v);  setPage(1) },
    dateFrom,
    setDateFrom: (v: string) => { setDateFromRaw(v); setPage(1) },
    dateTo,
    setDateTo:   (v: string) => { setDateToRaw(v);   setPage(1) },
    searchInput,
    setSearchInput: (v: string) => { setSearchInputRaw(v); setPage(1) },
    sortBy,
    setSortBy:  (v: TransactionSortBy) => { setSortByRaw(v);  setPage(1) },
    sortDir,
    setSortDir: (v: SortDir)           => { setSortDirRaw(v); setPage(1) },
    active,
    reset,
  }
}
