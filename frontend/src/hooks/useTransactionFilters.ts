import { useState } from 'react'
import { useDebounce } from './useDebounce'
import type { TransactionType } from '@/types'

export interface TransactionFilterParams {
  page: number
  page_size: number
  type?: TransactionType
  date_from?: string
  date_to?: string
  search?: string
}

export function useTransactionFilters() {
  const [page, setPage] = useState(1)
  const [type, setTypeRaw] = useState<string>('all')
  const [dateFrom, setDateFromRaw] = useState('')
  const [dateTo, setDateToRaw] = useState('')
  const [searchInput, setSearchInputRaw] = useState('')
  const debouncedSearch = useDebounce(searchInput, 350)

  const params: TransactionFilterParams = {
    page,
    page_size: 20,
    ...(type !== 'all' && { type: type as TransactionType }),
    ...(dateFrom && { date_from: dateFrom }),
    ...(dateTo && { date_to: dateTo }),
    ...(debouncedSearch && { search: debouncedSearch }),
  }

  return {
    params,
    page,
    setPage,
    type,
    setType: (v: string) => { setTypeRaw(v); setPage(1) },
    dateFrom,
    setDateFrom: (v: string) => { setDateFromRaw(v); setPage(1) },
    dateTo,
    setDateTo: (v: string) => { setDateToRaw(v); setPage(1) },
    searchInput,
    setSearchInput: (v: string) => { setSearchInputRaw(v); setPage(1) },
  }
}
