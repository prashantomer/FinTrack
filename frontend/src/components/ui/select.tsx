import * as React from "react"
import { Select as SelectPrimitive } from "@base-ui/react/select"

import { cn } from "@/lib/utils"
import { ChevronDownIcon, CheckIcon, ChevronUpIcon } from "lucide-react"

// ── Label registry ────────────────────────────────────────────────────────────
// base-ui's Select.Value doesn't reliably render ItemText, so we maintain our
// own value→label map and use it to display the selected label in the trigger.

interface Registry {
  register: (value: string, label: string) => void
  getLabel: (value: string) => string | undefined
  currentValue: string
}

const SelectRegistryCtx = React.createContext<Registry | null>(null)

function extractText(node: React.ReactNode): string {
  if (typeof node === "string" || typeof node === "number") return String(node)
  if (Array.isArray(node)) return node.map(extractText).join("")
  if (React.isValidElement(node))
    return extractText((node.props as { children?: React.ReactNode }).children)
  return ""
}

// ── Select (Root wrapper) ─────────────────────────────────────────────────────

type SelectProps = Omit<SelectPrimitive.Root.Props<string>, "onValueChange"> & {
  /** Fires when the user picks an option. Null is normalised to "" before reaching consumers. */
  onValueChange?: (value: string) => void
}

function Select({
  value: valueProp,
  defaultValue,
  onValueChange,
  children,
  ...props
}: SelectProps) {
  const [labels, setLabels] = React.useState<Map<string, string>>(() => new Map())

  const [currentValue, setCurrentValue] = React.useState<string>(
    (valueProp ?? defaultValue ?? "") as string
  )

  React.useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    if (valueProp !== undefined) setCurrentValue(valueProp as string)
  }, [valueProp])

  const register = React.useCallback((value: string, label: string) => {
    setLabels(prev => {
      if (prev.get(value) === label) return prev
      const next = new Map(prev)
      next.set(value, label)
      return next
    })
  }, [])

  const getLabel = React.useCallback(
    (value: string) => labels.get(value),
    [labels]
  )

  const handleValueChange = React.useCallback<
    NonNullable<SelectPrimitive.Root.Props<string>["onValueChange"]>
  >(
    (v) => {
      const next = v ?? ""
      setCurrentValue(next)
      onValueChange?.(next)
    },
    [onValueChange]
  )

  return (
    <SelectRegistryCtx.Provider value={{ register, getLabel, currentValue }}>
      <SelectPrimitive.Root
        value={valueProp}
        defaultValue={defaultValue}
        onValueChange={handleValueChange}
        {...props}
      >
        {children}
      </SelectPrimitive.Root>
    </SelectRegistryCtx.Provider>
  )
}

// ── SelectGroup ───────────────────────────────────────────────────────────────

function SelectGroup({ className, ...props }: SelectPrimitive.Group.Props) {
  return (
    <SelectPrimitive.Group
      data-slot="select-group"
      className={cn("scroll-my-1 p-1", className)}
      {...props}
    />
  )
}

// ── SelectValue ───────────────────────────────────────────────────────────────

function SelectValue({
  placeholder,
  className,
  children,
  ...props
}: { placeholder?: string; className?: string; children?: React.ReactNode }) {
  const registry = React.useContext(SelectRegistryCtx)
  const value = registry?.currentValue ?? ""
  const label = value ? registry?.getLabel(value) : undefined
  const isEmpty = !value && !children

  return (
    <span
      data-slot="select-value"
      className={cn(
        "flex flex-1 text-left",
        isEmpty && "text-muted-foreground",
        className
      )}
      {...props}
    >
      {children ?? (isEmpty ? placeholder : (label ?? value))}
    </span>
  )
}

// ── SelectTrigger ─────────────────────────────────────────────────────────────

function SelectTrigger({
  className,
  size = "default",
  children,
  ...props
}: SelectPrimitive.Trigger.Props & {
  size?: "sm" | "default"
}) {
  return (
    <SelectPrimitive.Trigger
      data-slot="select-trigger"
      data-size={size}
      className={cn(
        "flex w-full items-center justify-between gap-1.5 rounded-lg border border-input bg-transparent py-2 pr-2 pl-2.5 text-sm whitespace-nowrap transition-colors outline-none select-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 disabled:cursor-not-allowed disabled:opacity-50 data-[size=default]:h-8 data-[size=sm]:h-7 data-[size=sm]:rounded-[min(var(--radius-md),10px)] dark:bg-input/30 dark:hover:bg-input/50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
        className
      )}
      {...props}
    >
      {children}
      <SelectPrimitive.Icon
        render={
          <ChevronDownIcon className="pointer-events-none size-4 shrink-0 text-muted-foreground" />
        }
      />
    </SelectPrimitive.Trigger>
  )
}

// ── SelectContent ─────────────────────────────────────────────────────────────

function SelectContent({
  className,
  children,
  side = "bottom",
  sideOffset = 4,
  align = "center",
  alignOffset = 0,
  alignItemWithTrigger = true,
  ...props
}: SelectPrimitive.Popup.Props &
  Pick<
    SelectPrimitive.Positioner.Props,
    "align" | "alignOffset" | "side" | "sideOffset" | "alignItemWithTrigger"
  >) {
  return (
    <SelectPrimitive.Portal>
      <SelectPrimitive.Positioner
        side={side}
        sideOffset={sideOffset}
        align={align}
        alignOffset={alignOffset}
        alignItemWithTrigger={alignItemWithTrigger}
        className="isolate z-50"
      >
        <SelectPrimitive.Popup
          data-slot="select-content"
          data-align-trigger={alignItemWithTrigger}
          className={cn(
            "relative isolate z-50 max-h-(--available-height) w-(--anchor-width) min-w-36 origin-(--transform-origin) overflow-x-hidden overflow-y-auto rounded-lg bg-popover text-popover-foreground shadow-md ring-1 ring-foreground/10 duration-100",
            "data-[align-trigger=true]:animate-none",
            "data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95",
            "data-closed:animate-out data-closed:fade-out-0 data-closed:zoom-out-95 data-closed:pointer-events-none data-closed:invisible",
            className
          )}
          {...props}
        >
          <SelectScrollUpButton />
          <SelectPrimitive.List className="p-1">{children}</SelectPrimitive.List>
          <SelectScrollDownButton />
        </SelectPrimitive.Popup>
      </SelectPrimitive.Positioner>
    </SelectPrimitive.Portal>
  )
}

// ── SelectLabel ───────────────────────────────────────────────────────────────

function SelectLabel({ className, ...props }: SelectPrimitive.GroupLabel.Props) {
  return (
    <SelectPrimitive.GroupLabel
      data-slot="select-label"
      className={cn("px-1.5 py-1 text-xs text-muted-foreground", className)}
      {...props}
    />
  )
}

// ── SelectItem ────────────────────────────────────────────────────────────────

function SelectItem({ className, children, value, ...props }: SelectPrimitive.Item.Props) {
  const registry = React.useContext(SelectRegistryCtx)

  // Register value→label mapping synchronously on every render
  const label = React.useMemo(() => extractText(children as React.ReactNode), [children])
  React.useLayoutEffect(() => {
    if (value !== undefined && label) registry?.register(String(value), label)
  }, [value, label, registry])

  return (
    <SelectPrimitive.Item
      data-slot="select-item"
      value={value}
      className={cn(
        "relative flex w-full cursor-default items-center gap-1.5 rounded-md py-1.5 pr-8 pl-2 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
        className
      )}
      {...props}
    >
      <SelectPrimitive.ItemText className="flex flex-1 whitespace-nowrap">
        {children}
      </SelectPrimitive.ItemText>
      <SelectPrimitive.ItemIndicator
        render={
          <span className="pointer-events-none absolute right-2 flex size-4 items-center justify-center" />
        }
      >
        <CheckIcon className="size-3.5" />
      </SelectPrimitive.ItemIndicator>
    </SelectPrimitive.Item>
  )
}

// ── SelectSeparator ───────────────────────────────────────────────────────────

function SelectSeparator({ className, ...props }: SelectPrimitive.Separator.Props) {
  return (
    <SelectPrimitive.Separator
      data-slot="select-separator"
      className={cn("pointer-events-none -mx-1 my-1 h-px bg-border", className)}
      {...props}
    />
  )
}

// ── Scroll buttons ────────────────────────────────────────────────────────────

function SelectScrollUpButton({
  className,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.ScrollUpArrow>) {
  return (
    <SelectPrimitive.ScrollUpArrow
      data-slot="select-scroll-up-button"
      className={cn(
        "top-0 z-10 flex w-full cursor-default items-center justify-center bg-popover py-1 [&_svg:not([class*='size-'])]:size-4",
        className
      )}
      {...props}
    >
      <ChevronUpIcon />
    </SelectPrimitive.ScrollUpArrow>
  )
}

function SelectScrollDownButton({
  className,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.ScrollDownArrow>) {
  return (
    <SelectPrimitive.ScrollDownArrow
      data-slot="select-scroll-down-button"
      className={cn(
        "bottom-0 z-10 flex w-full cursor-default items-center justify-center bg-popover py-1 [&_svg:not([class*='size-'])]:size-4",
        className
      )}
      {...props}
    >
      <ChevronDownIcon />
    </SelectPrimitive.ScrollDownArrow>
  )
}

export {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectLabel,
  SelectScrollDownButton,
  SelectScrollUpButton,
  SelectSeparator,
  SelectTrigger,
  SelectValue,
}
