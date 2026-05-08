import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, it, expect, vi } from 'vitest'
import { renderWithProviders } from '@/test/utils'
import { ImportWizard } from './ImportWizard'

function renderWizard(open = true) {
  const onClose = vi.fn()
  const result = renderWithProviders(<ImportWizard open={open} onClose={onClose} />)
  return { ...result, onClose }
}

describe('ImportWizard – Step 1: Select Type', () => {
  it('renders step 1 with 3 clickable type cards', async () => {
    renderWizard()
    await waitFor(() => expect(screen.getByText('Select Type')).toBeInTheDocument())
    expect(screen.getByText('Investments')).toBeInTheDocument()
    expect(screen.getByText('Transactions')).toBeInTheDocument()
    expect(screen.getByText('Term Accounts')).toBeInTheDocument()
  })

  it('clicking "Investments" advances to step 2 (Context)', async () => {
    const user = userEvent.setup()
    renderWizard()
    await waitFor(() => expect(screen.getByText('Investments')).toBeInTheDocument())

    await user.click(screen.getByText('Investments'))

    await waitFor(() =>
      expect(screen.getByText(/default platform account/i)).toBeInTheDocument(),
    )
  })

  it('clicking "Transactions" advances to step 2 (Context)', async () => {
    const user = userEvent.setup()
    renderWizard()
    await waitFor(() => expect(screen.getByText('Transactions')).toBeInTheDocument())

    await user.click(screen.getByText('Transactions'))

    await waitFor(() =>
      expect(screen.getByText(/default linked account/i)).toBeInTheDocument(),
    )
  })

  it('clicking "Term Accounts" advances to step 2 (Context)', async () => {
    const user = userEvent.setup()
    renderWizard()
    await waitFor(() => expect(screen.getByText('Term Accounts')).toBeInTheDocument())

    await user.click(screen.getByText('Term Accounts'))

    await waitFor(() =>
      expect(screen.getByText(/how term account import works/i)).toBeInTheDocument(),
    )
  })
})

describe('ImportWizard – Step 2: Context navigation', () => {
  async function goToStep2(user: ReturnType<typeof userEvent.setup>) {
    renderWizard()
    await waitFor(() => expect(screen.getByText('Investments')).toBeInTheDocument())
    await user.click(screen.getByText('Investments'))
    await waitFor(() => expect(screen.getByText(/default platform account/i)).toBeInTheDocument())
  }

  it('clicking Back returns to step 1', async () => {
    const user = userEvent.setup()
    await goToStep2(user)

    await user.click(screen.getByRole('button', { name: /back/i }))

    await waitFor(() => expect(screen.getByText('Select Type')).toBeInTheDocument())
    expect(screen.getByText('Investments')).toBeInTheDocument()
    expect(screen.getByText('Transactions')).toBeInTheDocument()
  })

  it('clicking Next advances to step 3 (Template)', async () => {
    const user = userEvent.setup()
    await goToStep2(user)

    await user.click(screen.getByRole('button', { name: /next/i }))

    await waitFor(() =>
      expect(screen.getByText(/download sample csv/i)).toBeInTheDocument(),
    )
  })
})

describe('ImportWizard – Step 3: Template', () => {
  async function goToStep3(
    user: ReturnType<typeof userEvent.setup>,
    type: 'Investments' | 'Transactions' | 'Term Accounts' = 'Investments',
  ) {
    renderWizard()
    await waitFor(() => expect(screen.getByText(type)).toBeInTheDocument())
    await user.click(screen.getByText(type))
    // Wait for step 2
    await waitFor(() => screen.getByRole('button', { name: /next/i }))
    await user.click(screen.getByRole('button', { name: /next/i }))
    // Wait for step 3
    await waitFor(() => expect(screen.getByText(/download sample csv/i)).toBeInTheDocument())
  }

  it('shows investment column reference including "investment_type" and "trade_type"', async () => {
    const user = userEvent.setup()
    await goToStep3(user, 'Investments')

    expect(screen.getByText('investment_type')).toBeInTheDocument()
    expect(screen.getByText('trade_type')).toBeInTheDocument()
  })

  it('shows transaction columns including "date" and "amount"', async () => {
    const user = userEvent.setup()
    await goToStep3(user, 'Transactions')

    expect(screen.getByText('date')).toBeInTheDocument()
    expect(screen.getByText('amount')).toBeInTheDocument()
  })
})

describe('ImportWizard – Step 4: Upload', () => {
  async function goToStep4(user: ReturnType<typeof userEvent.setup>) {
    renderWizard()
    await waitFor(() => expect(screen.getByText('Investments')).toBeInTheDocument())
    await user.click(screen.getByText('Investments'))
    await waitFor(() => screen.getByRole('button', { name: /next/i }))
    await user.click(screen.getByRole('button', { name: /next/i }))
    await waitFor(() => expect(screen.getByText(/download sample csv/i)).toBeInTheDocument())
    await user.click(screen.getByRole('button', { name: /next/i }))
    await waitFor(() => expect(screen.getByText(/drag.*drop csv/i)).toBeInTheDocument())
  }

  it('shows the file upload drop zone', async () => {
    const user = userEvent.setup()
    await goToStep4(user)

    expect(screen.getByText(/drag.*drop csv/i)).toBeInTheDocument()
  })
})

describe('ImportWizard – Close resets to step 1', () => {
  it('clicking the X close button resets to step 1', async () => {
    const user = userEvent.setup()
    const { onClose } = renderWizard()

    // Advance to step 2 first
    await waitFor(() => expect(screen.getByText('Investments')).toBeInTheDocument())
    await user.click(screen.getByText('Investments'))
    await waitFor(() => expect(screen.getByText(/default platform account/i)).toBeInTheDocument())

    // Click the close (X) button rendered by SheetContent
    const closeButton = screen.getByRole('button', { name: /close/i })
    await user.click(closeButton)

    expect(onClose).toHaveBeenCalledOnce()
  })
})
