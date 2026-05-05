import { Component, type ErrorInfo, type ReactNode } from 'react'
import { reportError } from '@/lib/errorReporter'

interface Props {
  children: ReactNode
}

interface State {
  crashed: boolean
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { crashed: false }

  static getDerivedStateFromError(): State {
    return { crashed: true }
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    reportError(error.message, error.stack, info.componentStack ?? undefined)
  }

  render() {
    if (this.state.crashed) {
      return (
        <div className="flex flex-col items-center justify-center h-screen gap-4 text-center px-6">
          <p className="text-lg font-semibold">Something went wrong</p>
          <p className="text-sm text-muted-foreground">The error has been logged. Reload to try again.</p>
          <button
            className="text-sm underline text-muted-foreground"
            onClick={() => window.location.reload()}
          >
            Reload
          </button>
        </div>
      )
    }
    return this.props.children
  }
}
