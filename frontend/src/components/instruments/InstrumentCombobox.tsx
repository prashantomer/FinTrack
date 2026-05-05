import { useState } from 'react'
import { Check, ChevronsUpDown } from 'lucide-react'
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from '@/components/ui/command'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { useInstruments } from '@/hooks/useInstruments'
import { useDebounce } from '@/hooks/useDebounce'
import { INVESTMENT_TYPE_LABELS } from '@/lib/labels'
import type { InvestmentType } from '@/types'
import { cn } from '@/lib/utils'

interface Props {
  value: number | null
  onChange: (id: number | null) => void
  filterType?: InvestmentType
}

export function InstrumentCombobox({ value, onChange, filterType }: Props) {
  const [open, setOpen] = useState(false)
  const [inputValue, setInputValue] = useState('')
  const debouncedSearch = useDebounce(inputValue, 300)

  const { data: instruments = [] } = useInstruments({
    type: filterType,
    search: debouncedSearch || undefined,
    limit: 50,
  })

  const selected = instruments.find(i => i.id === value)

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger
        className={cn(
          'flex h-9 w-full items-center justify-between rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-xs',
          'hover:bg-accent hover:text-accent-foreground focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring',
          !selected && 'text-muted-foreground'
        )}
      >
        <span className="truncate">
          {selected ? `${selected.name} (${INVESTMENT_TYPE_LABELS[selected.type]})` : 'Select instrument…'}
        </span>
        <ChevronsUpDown size={14} className="ml-2 shrink-0 opacity-50" />
      </PopoverTrigger>
      <PopoverContent className="w-[var(--available-width)] p-0" align="start">
        <Command shouldFilter={false}>
          <CommandInput placeholder="Search instruments…" value={inputValue} onValueChange={setInputValue} />
          <CommandList>
            <CommandEmpty>No instruments found.</CommandEmpty>
            <CommandGroup>
              {value && (
                <CommandItem value="__clear__" onSelect={() => { onChange(null); setOpen(false) }} className="text-muted-foreground italic">
                  Clear selection
                </CommandItem>
              )}
              {instruments.map(inst => (
                <CommandItem key={inst.id} value={String(inst.id)} onSelect={() => { onChange(inst.id); setOpen(false) }}>
                  <Check size={14} className={cn('mr-2', value === inst.id ? 'opacity-100' : 'opacity-0')} />
                  <span className="flex-1">{inst.name}</span>
                  <span className="text-xs text-muted-foreground ml-2">
                    {inst.ticker_symbol && `${inst.ticker_symbol} · `}{INVESTMENT_TYPE_LABELS[inst.type]}
                  </span>
                </CommandItem>
              ))}
            </CommandGroup>
          </CommandList>
        </Command>
      </PopoverContent>
    </Popover>
  )
}
